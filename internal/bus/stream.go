// Package bus wraps the NATS JetStream calls aiaime needs: idempotent stream
// setup, publish, and sequence-offset fetch.
package bus

import (
	"context"
	"fmt"
	"strings"

	"github.com/nats-io/nats.go/jetstream"
)

const (
	// StreamName is the single JetStream stream that captures all aiaime
	// traffic across all bus IDs and topics.
	StreamName = "AIAIME"

	// SubjectPrefix is prepended to every NATS subject.
	SubjectPrefix = "aiaime"

	// SubjectPattern matches all aiaime subjects (all bus IDs, all topics).
	SubjectPattern = "aiaime.>"
)

// Subject returns the NATS subject for a given bus ID and topic.
// topic may contain dots; slashes are not valid in NATS subjects.
func Subject(busID, topic string) string {
	return fmt.Sprintf("%s.%s.%s", SubjectPrefix, busID, topic)
}

// TopicFromSubject extracts the topic portion from a full NATS subject.
// e.g. "aiaime.myproject.M1.C1" → "M1.C1"
func TopicFromSubject(busID, subject string) string {
	prefix := SubjectPrefix + "." + busID + "."
	return strings.TrimPrefix(subject, prefix)
}

// EnsureStreams creates the AIAIME stream if it doesn't already exist.
// Safe to call on every startup.
func EnsureStreams(ctx context.Context, js jetstream.JetStream) error {
	_, err := js.CreateOrUpdateStream(ctx, jetstream.StreamConfig{
		Name:     StreamName,
		Subjects: []string{SubjectPattern},
		Storage:  jetstream.FileStorage,
	})
	if err != nil {
		return fmt.Errorf("ensure %s stream: %w", StreamName, err)
	}
	return nil
}
