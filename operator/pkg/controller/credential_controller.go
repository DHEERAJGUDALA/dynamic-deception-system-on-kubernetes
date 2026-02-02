package controller

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"time"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
)

// CredentialReconciler manages decoy credentials
type CredentialReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

const (
	decoyCredentialLabel = "deception.k8s.io/decoy-credential"
	credentialTypeKey    = "deception.k8s.io/credential-type"
)

// CredentialType defines the type of decoy credential
type CredentialType string

const (
	CredentialTypeSSH      CredentialType = "ssh"
	CredentialTypeDatabase CredentialType = "database"
	CredentialTypeAPI      CredentialType = "api"
	CredentialTypeAWS      CredentialType = "aws"
)

func (r *CredentialReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)
	logger.Info("Reconciling Credential", "namespace", req.Namespace, "name", req.Name)

	secret := &corev1.Secret{}
	err := r.Get(ctx, req.NamespacedName, secret)
	if err != nil {
		if errors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	// Check if this is a decoy credential
	labels := secret.GetLabels()
	if labels == nil || labels[decoyCredentialLabel] != "true" {
		return ctrl.Result{}, nil
	}

	// Check rotation
	if r.needsRotation(secret) {
		credType := CredentialType(labels[credentialTypeKey])
		logger.Info("Rotating decoy credential", "secret", secret.Name, "type", credType)

		if err := r.rotateCredential(ctx, secret, credType); err != nil {
			logger.Error(err, "Failed to rotate credential")
			return ctrl.Result{RequeueAfter: 5 * time.Minute}, err
		}
	}

	return ctrl.Result{RequeueAfter: 4 * time.Hour}, nil
}

func (r *CredentialReconciler) needsRotation(secret *corev1.Secret) bool {
	annotations := secret.GetAnnotations()
	if annotations == nil {
		return true
	}

	lastRotationStr, ok := annotations[lastRotationKey]
	if !ok {
		return true
	}

	lastRotation, err := time.Parse(time.RFC3339, lastRotationStr)
	if err != nil {
		return true
	}

	intervalStr := annotations[rotationIntervalKey]
	if intervalStr == "" {
		intervalStr = "12h"
	}

	interval, err := time.ParseDuration(intervalStr)
	if err != nil {
		interval = 12 * time.Hour
	}

	return time.Since(lastRotation) > interval
}

func (r *CredentialReconciler) rotateCredential(ctx context.Context, secret *corev1.Secret, credType CredentialType) error {
	var newData map[string][]byte
	var err error

	switch credType {
	case CredentialTypeSSH:
		newData, err = generateSSHCredential()
	case CredentialTypeDatabase:
		newData, err = generateDatabaseCredential()
	case CredentialTypeAPI:
		newData, err = generateAPICredential()
	case CredentialTypeAWS:
		newData, err = generateAWSCredential()
	default:
		newData, err = generateGenericCredential()
	}

	if err != nil {
		return err
	}

	secret.Data = newData
	if secret.Annotations == nil {
		secret.Annotations = make(map[string]string)
	}
	secret.Annotations[lastRotationKey] = time.Now().Format(time.RFC3339)

	return r.Update(ctx, secret)
}

func generateSSHCredential() (map[string][]byte, error) {
	password := generateRandomString(16)
	return map[string][]byte{
		"username": []byte("admin"),
		"password": []byte(password),
	}, nil
}

func generateDatabaseCredential() (map[string][]byte, error) {
	password := generateRandomString(24)
	return map[string][]byte{
		"username": []byte("db_admin"),
		"password": []byte(password),
		"database": []byte("production"),
		"host":     []byte("db.internal.local"),
	}, nil
}

func generateAPICredential() (map[string][]byte, error) {
	apiKey := generateRandomString(32)
	apiSecret := generateRandomString(64)
	return map[string][]byte{
		"api_key":    []byte(apiKey),
		"api_secret": []byte(apiSecret),
	}, nil
}

func generateAWSCredential() (map[string][]byte, error) {
	// Generate fake AWS credentials (clearly marked as decoys)
	accessKey := "AKIA" + generateRandomString(16)
	secretKey := generateRandomString(40)
	return map[string][]byte{
		"aws_access_key_id":     []byte(accessKey),
		"aws_secret_access_key": []byte(secretKey),
		"aws_region":            []byte("us-east-1"),
	}, nil
}

func generateGenericCredential() (map[string][]byte, error) {
	token := generateRandomString(32)
	return map[string][]byte{
		"token": []byte(token),
	}, nil
}

func generateRandomString(length int) string {
	b := make([]byte, length)
	rand.Read(b)
	return base64.URLEncoding.EncodeToString(b)[:length]
}

// CreateDecoyCredential creates a new decoy credential secret
func CreateDecoyCredential(namespace, name string, credType CredentialType) *corev1.Secret {
	return &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: namespace,
			Labels: map[string]string{
				decoyCredentialLabel: "true",
				credentialTypeKey:    string(credType),
			},
			Annotations: map[string]string{
				rotationIntervalKey: "12h",
				lastRotationKey:     time.Now().Format(time.RFC3339),
			},
		},
		Type: corev1.SecretTypeOpaque,
	}
}

func (r *CredentialReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&corev1.Secret{}).
		Complete(r)
}
