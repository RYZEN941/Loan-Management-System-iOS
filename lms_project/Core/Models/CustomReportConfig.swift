import Foundation

public struct CustomReportConfig: Codable, Equatable {
    public var metrics: [String]
    public var dimensions: [String]
    public var filters: ReportFilters
    public var visualization: VisualizationType

    public struct ReportFilters: Codable, Equatable {
        public var dateRange: String
        public var loanType: String
        public var region: String
        public var status: String

        public init(dateRange: String, loanType: String, region: String, status: String) {
            self.dateRange = dateRange
            self.loanType = loanType
            self.region = region
            self.status = status
        }
    }

    public enum VisualizationType: String, Codable, CaseIterable, Equatable {
        case line = "Line Chart"
        case bar = "Bar Chart"
        case pie = "Pie Chart"
    }

    public init(metrics: [String], dimensions: [String], filters: ReportFilters, visualization: VisualizationType) {
        self.metrics = metrics
        self.dimensions = dimensions
        self.filters = filters
        self.visualization = visualization
    }
}

public struct CustomReportKPI: Codable, Equatable {
    public let title: String
    public let value: String
    public let note: String

    public init(title: String, value: String, note: String) {
        self.title = title
        self.value = value
        self.note = note
    }
}

public struct CustomReportBucket: Codable, Equatable {
    public let name: String
    public let value: String
    public let count: String

    public init(name: String, value: String, count: String) {
        self.name = name
        self.value = value
        self.count = count
    }
}

public struct CustomReportTrendPoint: Codable, Equatable {
    public let period: String
    public let value: String

    public init(period: String, value: String) {
        self.period = period
        self.value = value
    }
}

public struct CustomReportPayload: Codable, Equatable {
    public let config: CustomReportConfig
    public let kpis: [CustomReportKPI]
    public let groupedData: [CustomReportBucket]
    public let trendData: [CustomReportTrendPoint]
    public let generatedAt: Date

    public init(config: CustomReportConfig, kpis: [CustomReportKPI], groupedData: [CustomReportBucket], trendData: [CustomReportTrendPoint], generatedAt: Date) {
        self.config = config
        self.kpis = kpis
        self.groupedData = groupedData
        self.trendData = trendData
        self.generatedAt = generatedAt
    }
}
