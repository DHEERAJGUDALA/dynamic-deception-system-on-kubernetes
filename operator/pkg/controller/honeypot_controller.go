package controller

import (
	"context"
	"time"

	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
)

// HoneypotReconciler reconciles Honeypot resources
type HoneypotReconciler struct {
	client.Client
	Scheme  *runtime.Scheme
	Profile string
}

// +kubebuilder:rbac:groups=deception.k8s.io,resources=honeypots,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=deception.k8s.io,resources=honeypots/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=deception.k8s.io,resources=honeypots/finalizers,verbs=update
// +kubebuilder:rbac:groups="",resources=pods,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=configmaps,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups="",resources=secrets,verbs=get;list;watch;create;update;patch;delete

func (r *HoneypotReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)
	logger.Info("Reconciling Honeypot", "namespace", req.Namespace, "name", req.Name)

	// Fetch the Honeypot instance
	honeypot := &corev1.Pod{}
	err := r.Get(ctx, req.NamespacedName, honeypot)
	if err != nil {
		if errors.IsNotFound(err) {
			logger.Info("Honeypot resource not found. Ignoring since object must be deleted")
			return ctrl.Result{}, nil
		}
		logger.Error(err, "Failed to get Honeypot")
		return ctrl.Result{}, err
	}

	// Check if honeypot has required labels
	labels := honeypot.GetLabels()
	if labels == nil || labels["component"] != "honeypot" {
		return ctrl.Result{}, nil
	}

	// Apply resource constraints based on profile
	if err := r.applyResourceConstraints(ctx, honeypot); err != nil {
		logger.Error(err, "Failed to apply resource constraints")
		return ctrl.Result{RequeueAfter: 30 * time.Second}, err
	}

	// Update honeypot status
	if err := r.updateStatus(ctx, honeypot); err != nil {
		logger.Error(err, "Failed to update status")
		return ctrl.Result{RequeueAfter: 10 * time.Second}, err
	}

	// Requeue based on profile
	requeueAfter := r.getRequeueInterval()
	return ctrl.Result{RequeueAfter: requeueAfter}, nil
}

func (r *HoneypotReconciler) applyResourceConstraints(ctx context.Context, pod *corev1.Pod) error {
	// Apply memory and CPU limits based on profile
	// This would typically modify the pod spec
	return nil
}

func (r *HoneypotReconciler) updateStatus(ctx context.Context, pod *corev1.Pod) error {
	// Update the honeypot status with metrics
	return nil
}

func (r *HoneypotReconciler) getRequeueInterval() time.Duration {
	switch r.Profile {
	case "light":
		return 60 * time.Second
	case "medium":
		return 30 * time.Second
	case "heavy":
		return 15 * time.Second
	default:
		return 30 * time.Second
	}
}

// SetupWithManager sets up the controller with the Manager
func (r *HoneypotReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&corev1.Pod{}).
		Complete(r)
}
