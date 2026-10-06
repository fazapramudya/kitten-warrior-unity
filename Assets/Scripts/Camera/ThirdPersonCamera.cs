using UnityEngine;

namespace KittenWarrior.Camera
{
    /// <summary>
    /// Smooth third-person orbital camera controller.
    /// Features mouse orbit, pitch clamping, and collision zoom to prevent clipping through trees and geometry.
    /// Owned by: Worker-1-Gameplay
    /// </summary>
    [DisallowMultipleComponent]
    public class ThirdPersonCamera : MonoBehaviour
    {
        [Header("Target & Focal Point")]
        [Tooltip("Target transform to orbit around (Player).")]
        [SerializeField] private Transform target;

        [Tooltip("Offset relative to target position (focuses on cat upper body/head).")]
        [SerializeField] private Vector3 targetOffset = new Vector3(0f, 1.1f, 0f);

        [Header("Distance & Zoom")]
        [SerializeField] private float defaultDistance = 3.8f;
        [SerializeField] private float minDistance = 0.9f;
        [SerializeField] private float maxDistance = 5.5f;

        [Header("Mouse Sensitivity & Clamping")]
        [SerializeField] private float mouseSensitivityX = 150f;
        [SerializeField] private float mouseSensitivityY = 120f;
        [SerializeField] private float minPitch = -25f;
        [SerializeField] private float maxPitch = 70f;
        [SerializeField] private float smoothDampTime = 0.04f;

        [Header("Anti-Clipping Collision")]
        [Tooltip("Layer mask for environment obstacles (walls, terrain, trees).")]
        [SerializeField] private LayerMask collisionLayers = ~0;

        [Tooltip("Radius of sphere cast for obstacle detection.")]
        [SerializeField] private float collisionRadius = 0.22f;

        [Tooltip("Damping speed when expanding back from collision.")]
        [SerializeField] private float collisionDamping = 14f;

        private float yaw;
        private float pitch = 15f;
        private float currentDistance;
        private float targetDistance;
        private Vector3 currentVelocity;

        private void Start()
        {
            Cursor.lockState = CursorLockMode.Locked;
            Cursor.visible = false;

            currentDistance = defaultDistance;
            targetDistance = defaultDistance;

            if (target != null)
            {
                yaw = target.eulerAngles.y;
            }
        }

        private void LateUpdate()
        {
            if (target == null) return;

            // Read mouse look inputs
            float mouseX = Input.GetAxis("Mouse X") * mouseSensitivityX * Time.deltaTime;
            float mouseY = Input.GetAxis("Mouse Y") * mouseSensitivityY * Time.deltaTime;

            yaw += mouseX;
            pitch = Mathf.Clamp(pitch - mouseY, minPitch, maxPitch);

            // Optional zoom via mouse scroll wheel
            float scroll = Input.GetAxis("Mouse ScrollWheel");
            if (Mathf.Abs(scroll) > 0.01f)
            {
                targetDistance = Mathf.Clamp(targetDistance - (scroll * 3f), minDistance, maxDistance);
            }

            Vector3 focusPoint = target.position + targetOffset;
            Quaternion rotation = Quaternion.Euler(pitch, yaw, 0f);
            Vector3 cameraDirection = rotation * -Vector3.forward;

            // Handle Anti-Clipping Collision Check
            float computedDistance = targetDistance;
            if (Physics.SphereCast(focusPoint, collisionRadius, cameraDirection, out RaycastHit hit, targetDistance, collisionLayers, QueryTriggerInteraction.Ignore))
            {
                computedDistance = Mathf.Clamp(hit.distance - collisionRadius, minDistance, targetDistance);
            }

            // Smoothly adjust current distance
            currentDistance = Mathf.Lerp(currentDistance, computedDistance, Time.deltaTime * collisionDamping);

            Vector3 desiredPosition = focusPoint + (cameraDirection * currentDistance);
            transform.position = Vector3.SmoothDamp(transform.position, desiredPosition, ref currentVelocity, smoothDampTime);
            transform.LookAt(focusPoint);
        }

        public void SetTarget(Transform newTarget)
        {
            target = newTarget;
            if (target != null) yaw = target.eulerAngles.y;
        }
    }
}
