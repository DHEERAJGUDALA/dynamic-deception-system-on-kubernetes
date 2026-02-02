package controller

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"time"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
)

// CanaryTokenReconciler reconciles CanaryToken secrets
type CanaryTokenReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

const (
	canaryTokenLabel     = "deception.k8s.io/canary-token"
	rotationIntervalKey  = "deception.k8s.io/rotation-interval"
	lastRotationKey      = "deception.k8s.io/last-rotation"
)

func (r *CanaryTokenReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)
	logger.Info("Reconciling CanaryToken", "namespace", req.Namespace, "name", req.Name)

	secret := &corev1.Secret{}
	err := r.Get(ctx, req.NamespacedName, secret)
	if err != nil {
		if errors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	// Check if this is a canary token secret
	labels := secret.GetLabels()
	if labels == nil || labels[canaryTokenLabel] != "true" {
		return ctrl.Result{}, nil
	}

	// Check if rotation is needed
	if r.needsRotation(secret) {
		logger.Info("Rotating canary token", "secret", secret.Name)
		if err := r.rotateToken(ctx, secret); err != nil {
			logger.Error(err, "Failed to rotate canary token")
			return ctrl.Result{RequeueAfter: 5 * time.Minute}, err
		}
	}

	// Requeue for next rotation check
	return ctrl.Result{RequeueAfter: 1 * time.Hour}, nil
}

func (r *CanaryTokenReconciler) needsRotation(secret *corev1.Secret) bool {
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
		intervalStr = "6h"
	}

	interval, err := time.ParseDuration(intervalStr)
	if err != nil {
		interval = 6 * time.Hour
	}

	return time.Since(lastRotation) > interval
}

func (r *CanaryTokenReconciler) rotateToken(ctx context.Context, secret *corev1.Secret) error {
	// Generate new token
	token := make([]byte, 32)
	if _, err := rand.Read(token); err != nil {
		return err
	}

	// Update secret data
	if secret.Data == nil {
		secret.Data = make(map[string][]byte)
	}
	secret.Data["token"] = []byte(hex.EncodeToString(token))

	// Update rotation timestamp
	if secret.Annotations == nil {
		secret.Annotations = make(map[string]string)
	}
	secret.Annotations[lastRotationKey] = time.Now().Format(time.RFC3339)

	return r.Update(ctx, secret)
}

// GenerateCanaryToken creates a new canary token secret
func GenerateCanaryToken(namespace, name string, rotationInterval time.Duration) *corev1.Secret {
	token := make([]byte, 32)
	rand.Read(token)

	return &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: namespace,
			Labels: map[string]string{
				canaryTokenLabel: "true",
			},
			Annotations: map[string]string{
				rotationIntervalKey: rotationInterval.String(),
				lastRotationKey:     time.Now().Format(time.RFC3339),
			},
		},
		Type: corev1.SecretTypeOpaque,
		Data: map[string][]byte{
			"token": []byte(hex.EncodeToString(token)),
		},
	}
}

func (r *CanaryTokenReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&corev1.Secret{}).
		Complete(r)
}
