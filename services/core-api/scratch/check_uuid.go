package main

import (
	"fmt"
	"github.com/jackc/pgx/v5/pgtype"
)

func main() {
	u := pgtype.UUID{Bytes: [16]byte{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}, Valid: true}
	fmt.Printf("Valid String: %s\n", u.String())
	u2 := pgtype.UUID{Valid: false}
	fmt.Printf("Invalid String: %s\n", u2.String())
}
