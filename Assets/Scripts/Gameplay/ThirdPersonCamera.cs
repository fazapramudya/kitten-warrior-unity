using UnityEngine;

namespace KittenWarrior.Gameplay
{
    /// <summary>
    /// Smooth third-person orbital camera controller with collision detection.
    /// Owned by: Felix (Gameplay Lead)
    /// </summary>
    public class ThirdPersonCamera : MonoBehaviour
    {
        [Header("Target & Positioning")]
        [SerializeField] private Transform target;
        [SerializeField] private Vector3 targetOffset = new Vector3(0f, 1.2f, 0f);
        [SerializeField] private float defaultDistance = 4.2f;
        [SerializeField] private float minDistance = 1.0f;
        [SerializeField] private float maxDistance = 6.0f;

        [Header("Orbit & Sensitivity")]
        [SerializeField] private float mouseSensitivityX = 160f;
        [SerializeField] private float mouseSensitivityY = 120f;
        [SerializeField] private float minPitch = -25f;
        [SerializeField] private float maxPitch = 70f;
        [SerializeField] private float smoothTime = 0.05f;

        [Header("Collision Zoom")]
        [SerializeField] private LayerMask collisionLayers = ~0;
        [SerializeField] private float collisionRadius = 0.25f;
        [SerializeField] private float collisionDamping = 12f;

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

            // Read Mouse Look Inputs
            float mouseX = Input.GetAxis("Mouse X") * mouseSensitivityX * Time.deltaTime;
            float mouseY = Input.GetAxis("Mouse Y") * mouseSensitivityY * Time.deltaTime;

            yaw += mouseX;
            pitch = Mathf.Clamp(pitch - mouseY, minPitch, maxPitch);

            // Zoom via scroll wheel
            float scroll = Input.GetAxis("Mouse ScrollWheel");
            if (Mathf.Abs(scroll) > 0.01f)
            {
                targetDistance = Mathf.Clamp(targetDistance - (scroll * 3f), minDistance, maxDistance);
            }

            Vector3 focusPoint = target.position + targetOffset;
            Quaternion rotation = Quaternion.Euler(pitch, yaw, 0f);
            Vector3 desiredDir = rotation * -Vector3.forward;

            // Handle Camera Obstruction / Collision Zoom
            float computedDistance = targetDistance;
            if (Physics.SphereCast(focusPoint, collisionRadius, desiredDir, out RaycastHit hit, targetDistance, collisionLayers, QueryTriggerInteraction.Ignore))
            {
                computedDistance = Mathf.Clamp(hit.distance - collisionRadius, minDistance, targetDistance);
            }

            currentDistance = Mathf.Lerp(currentDistance, computedDistance, Time.deltaTime * collisionDamping);

            Vector3 desiredPos = focusPoint + (desiredDir * currentDistance);
            transform.position = Vector3.SmoothDamp(transform.position, desiredPos, ref currentVelocity, smoothTime);
            transform.LookAt(focusPoint);
        }

        public void SetTarget(Transform newTarget)
        {
            target = newTarget;
        }
    }
}
