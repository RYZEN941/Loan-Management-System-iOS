package audit

import (
	"context"
	"encoding/json"
	"log"

	"github.com/chirag3003/lms-monorepo/services/core-api/internal/repository/generated"
	"github.com/chirag3003/lms-monorepo/services/core-api/internal/transport/grpc/interceptors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
)

type service struct {
	queries generated.Querier
	logChan chan interceptors.AuditEntry
}

func NewService(queries generated.Querier) interceptors.AuditService {
	s := &service{
		queries: queries,
		logChan: make(chan interceptors.AuditEntry, 100),
	}
	go s.worker()
	return s
}

func (s *service) Record(ctx context.Context, entry interceptors.AuditEntry) {
	select {
	case s.logChan <- entry:
	default:
		log.Printf("audit log channel full, dropping entry: %v", entry.Action)
	}
}

func (s *service) worker() {
	for entry := range s.logChan {
		ctx := context.Background()
		payloadJSON, _ := json.Marshal(entry.Payload)
		changesJSON, _ := json.Marshal(entry.Changes)

		_, err := s.queries.CreateAuditLog(ctx, generated.CreateAuditLogParams{
			ActorID:      pgtype.UUID{Bytes: entry.ActorID, Valid: entry.ActorID != uuid.Nil},
			ActorRole:    generated.NullUserRole{UserRole: generated.UserRole(entry.ActorRole), Valid: entry.ActorRole != ""},
			Action:       entry.Action,
			ResourceType: pgtype.Text{String: entry.ResourceType, Valid: entry.ResourceType != ""},
			ResourceID:   pgtype.UUID{Bytes: entry.ResourceID, Valid: entry.ResourceID != uuid.Nil},
			Payload:      payloadJSON,
			Changes:      changesJSON,
			StatusCode:   pgtype.Text{String: entry.StatusCode, Valid: entry.StatusCode != ""},
			IpAddress:    pgtype.Text{String: entry.IPAddress, Valid: entry.IPAddress != ""},
			UserAgent:    pgtype.Text{String: entry.UserAgent, Valid: entry.UserAgent != ""},
		})
		if err != nil {
			log.Printf("failed to persist audit log: %v", err)
		}
	}
}
