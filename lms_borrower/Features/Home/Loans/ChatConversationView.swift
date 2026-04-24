import SwiftUI
import Combine

@MainActor
@available(iOS 18.0, *)
class ChatConversationViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = true
    @Published var errorMessage: String? = nil
    @Published var participantName: String = "User"

    private let chatService: ChatServiceProtocol
    private let roomID: String
    private var messageStreamTask: Task<Void, Never>?

    init(roomID: String, chatService: ChatServiceProtocol = ServiceContainer.chatService) {
        self.roomID = roomID
        self.chatService = chatService
        loadMessages()
        startStreaming()
    }

    deinit {
        messageStreamTask?.cancel()
    }

    // MARK: - Data Loading

    func loadMessages() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let loadedMessages = try await chatService.listRoomMessages(
                    roomID: roomID,
                    limit: 100,
                    offset: 0
                )
                await MainActor.run {
                    self.messages = loadedMessages.reversed() // Show newest at bottom
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Streaming

    private func startStreaming() {
        messageStreamTask = Task {
            let stream = chatService.subscribeToRoomMessages(roomID: roomID)

            do {
                for try await event in stream {
                    if Task.isCancelled { break }

                    if !event.isHeartbeat, let newMessage = event.message {
                        await MainActor.run {
                            // Add new message if not already present
                            if !self.messages.contains(where: { $0.id == newMessage.id }) {
                                self.messages.append(newMessage)
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Sending Messages

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let text = inputText.trimmingCharacters(in: .whitespaces)
        inputText = ""

        Task {
            do {
                let sentMessage = try await chatService.sendMessage(
                    roomID: roomID,
                    body: text,
                    messageType: .text,
                    metadataJSON: nil
                )
                await MainActor.run {
                    // Optimistically add message (stream will also deliver it)
                    if !self.messages.contains(where: { $0.id == sentMessage.id }) {
                        self.messages.append(sentMessage)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.inputText = text // Restore text on error
                }
            }
        }
    }

    func refresh() {
        loadMessages()
    }
}

struct ChatConversationView: View {
    let roomID: String

    @StateObject private var viewModel: ChatConversationViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scrollOffset: CGFloat = 0

    init(roomID: String) {
        self.roomID = roomID
        _viewModel = StateObject(wrappedValue: ChatConversationViewModel(roomID: roomID))
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top

            ZStack(alignment: .top) {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView("Loading messages...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { scrollProxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 0) {
                                ChatScrollOffsetReader()
                                    .frame(height: 0)
                                LazyVStack(spacing: 2) {
                                    ForEach(viewModel.messages) { message in
                                        ChatBubble(message: message, participantName: viewModel.participantName)
                                            .id(message.id)
                                    }
                                }
                                .padding(.top, topInset + 62)
                                .padding(.bottom, 24)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .coordinateSpace(name: "ChatConversationScroll")
                        .onPreferenceChange(ChatScrollOffsetKey.self) { value in
                            scrollOffset = value
                        }
                        .onAppear {
                            if let last = viewModel.messages.last {
                                DispatchQueue.main.async {
                                    scrollProxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            if let last = viewModel.messages.last {
                                withAnimation(.easeOut(duration: 0.22)) {
                                    scrollProxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                        .refreshable {
                            viewModel.refresh()
                        }
                    }
                }

                MessagesNavigationBar(
                    participantName: viewModel.participantName,
                    dismiss: dismiss,
                    scrollOffset: scrollOffset,
                    topInset: topInset
                )
                .ignoresSafeArea(edges: .top)
            }
            .safeAreaInset(edge: .bottom) {
                InputBarView(viewModel: viewModel)
                    .background(.regularMaterial)
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationBarBackButtonHidden(true)
        .navigationBarHidden(true)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

struct MessagesNavigationBar: View {
    let participantName: String
    let dismiss: DismissAction
    let scrollOffset: CGFloat
    let topInset: CGFloat

    private var collapseProgress: CGFloat {
        min(max(-scrollOffset / 100, 0), 1)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Color(UIColor.systemBackground)
                        .opacity(0.7 * collapseProgress)
                )
                .opacity(0.18 + (0.82 * collapseProgress))

            Divider()
                .opacity(collapseProgress)

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 17))
                    }
                    .foregroundColor(.mainBlue)
                }
                .frame(width: 72, alignment: .leading)

                Spacer()

                VStack(spacing: 1) {
                    Circle()
                        .fill(DS.primaryLight)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text(String(participantName.prefix(1)))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.mainBlue)
                        )
                        .scaleEffect(0.84 + (0.16 * collapseProgress))

                    VStack(spacing: 1) {
                        Text(participantName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text("Support Agent")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .opacity(0.18 + (0.82 * collapseProgress))
                }
                .frame(maxWidth: .infinity)

                Spacer()

                HStack(spacing: 18) {
                    Button {} label: {
                        Image(systemName: "phone.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.mainBlue)
                    }

                    Button {} label: {
                        Image(systemName: "video.fill")
                            .font(.system(size: 17))
                            .foregroundColor(.mainBlue)
                    }
                }
                .frame(width: 72, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.top, topInset + 6)
            .padding(.bottom, 10)
        }
        .frame(height: topInset + 54)
    }
}


struct ChatBubble: View {
    let message: ChatMessage
    let participantName: String
    // TODO: Get current user ID from auth service
    private let currentUserID = ""

    var isCurrentUser: Bool {
        message.isFromCurrentUser(currentUserID: currentUserID)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 6) {
                if isCurrentUser {
                    Spacer(minLength: 60)
                } else {
                    Circle()
                        .fill(DS.primaryLight)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Text(String(participantName.prefix(1)))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.mainBlue)
                        )
                }

                Text(message.body)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1.5)
                    .foregroundColor(isCurrentUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 255, alignment: isCurrentUser ? .trailing : .leading)
                    .background(
                        isCurrentUser
                            ? DS.primary
                            : Color(UIColor.secondarySystemGroupedBackground)
                    )
                    .clipShape(BubbleShape(isCurrentUser: isCurrentUser))

                if !isCurrentUser {
                    Spacer(minLength: 60)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 2)

            HStack {
                if isCurrentUser {
                    Spacer()
                }

                Text(message.formattedTime)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, isCurrentUser ? 18 : 50)

                if !isCurrentUser {
                    Spacer()
                }
            }
            .padding(.bottom, 6)
        }
    }
}

struct BubbleShape: Shape {
    let isCurrentUser: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tail: CGFloat = 6
        var path = Path()

        if isCurrentUser {
            path.addRoundedRect(
                in: CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )

            let tailX = rect.maxX - tail
            path.move(to: CGPoint(x: tailX, y: rect.maxY - 10))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: tailX, y: rect.maxY - 4))
        } else {
            path.addRoundedRect(
                in: CGRect(x: tail, y: rect.minY, width: rect.width - tail, height: rect.height),
                cornerSize: CGSize(width: radius, height: radius)
            )

            path.move(to: CGPoint(x: tail, y: rect.maxY - 10))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: tail, y: rect.maxY - 4))
        }

        return path
    }
}

struct InputBarView: View {
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 10) {
                Button {} label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.mainBlue)
                }

                HStack {
                    TextField("iMessage", text: $viewModel.inputText)
                        .font(.system(size: 16))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    if !viewModel.inputText.isEmpty {
                        Button {
                            viewModel.sendMessage()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.mainBlue)
                        }
                        .padding(.trailing, 4)
                    }
                }
                .background(Color(UIColor.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(UIColor.separator), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color.clear)
        }
    }
}

struct ChatScrollOffsetReader: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: ChatScrollOffsetKey.self,
                value: geometry.frame(in: .named("ChatConversationScroll")).minY
            )
        }
    }
}

struct ChatScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
