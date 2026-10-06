using System;
using System.Collections;
using UnityEngine;

namespace KittenWarrior.Player
{
    public enum MovementState
    {
        Idle,
        Walking,
        Sprinting,
        Jumping,
        Falling,
        DodgeRolling
    }

    /// <summary>
    /// Feline character locomotion controller.
    /// Handles camera-relative movement, smooth rotation, jumping, dodge-roll, and knockback absorption.
    /// Owned by: Worker-1-Gameplay
    /// </summary>
    [RequireComponent(typeof(CharacterController))]
    [DisallowMultipleComponent]
    public class PlayerController : MonoBehaviour
    {
        [Header("Locomotion Tuning")]
        [Tooltip("Standard walking speed for feline traversal.")]
        [SerializeField] private float walkSpeed = 4.2f;

        [Tooltip("Sprint speed for rapid evasion and traversal.")]
        [SerializeField] private float sprintSpeed = 7.5f;

        [Tooltip("Smooth time for rotating towards camera direction.")]
        [SerializeField] private float rotationSmoothTime = 0.08f;

        [Header("Jump & Vertical Physics")]
        [SerializeField] private float jumpHeight = 1.35f;
        [SerializeField] private float gravity = -20f;
        [SerializeField] private float coyoteTimeDuration = 0.15f;
        [SerializeField] private float jumpBufferDuration = 0.15f;

        [Header("Dodge Roll (Evasion)")]
        [SerializeField] private float dodgeSpeed = 10f;
        [SerializeField] private float dodgeDuration = 0.38f;
        [SerializeField] private float dodgeStaminaCost = 25f;
        [SerializeField] private float sprintStaminaCostPerSec = 14f;
        [SerializeField] private float jumpStaminaCost = 15f;

        [Header("References")]
        [SerializeField] private Transform cameraTransform;
        [SerializeField] private StaminaSystem staminaSystem;

        private CharacterController characterController;
        private MovementState currentState = MovementState.Idle;

        private Vector3 moveVelocity;
        private Vector3 knockbackVelocity;
        private float verticalVelocity;
        private float currentTurnVelocity;
        private float coyoteTimer;
        private float jumpBufferTimer;
        private bool isGrounded;
        private bool isDodgeRolling;
        private Vector3 rollDirection;

        public MovementState CurrentState => currentState;
        public bool IsGrounded => isGrounded;
        public bool IsDodgeRolling => isDodgeRolling;
        public Vector3 Velocity => characterController.velocity;

        public event Action<MovementState> OnStateChanged;
        public event Action OnJumped;
        public event Action OnDodgeRollStarted;

        private void Awake()
        {
            characterController = GetComponent<CharacterController>();
            if (staminaSystem == null) staminaSystem = GetComponent<StaminaSystem>();

            if (cameraTransform == null && Camera.main != null)
            {
                cameraTransform = Camera.main.transform;
            }
        }

        private void Update()
        {
            UpdateGroundedState();

            if (isDodgeRolling)
            {
                HandleDodgeRollMovement();
                return;
            }

            ReadLocomotionInput();
            HandleJumpAndGravity();
            ApplyKnockbackDecay();
            ApplyFinalMovement();
        }

        private void UpdateGroundedState()
        {
            isGrounded = characterController.isGrounded;

            if (isGrounded)
            {
                coyoteTimer = coyoteTimeDuration;
                if (verticalVelocity < 0f)
                {
                    // Gentle grounding stick force
                    verticalVelocity = -2f;
                }
            }
            else
            {
                coyoteTimer -= Time.deltaTime;
            }

            if (jumpBufferTimer > 0f)
            {
                jumpBufferTimer -= Time.deltaTime;
            }
        }

        private void ReadLocomotionInput()
        {
            float horizontal = Input.GetAxisRaw("Horizontal");
            float vertical = Input.GetAxisRaw("Vertical");
            Vector3 inputDir = new Vector3(horizontal, 0f, vertical).normalized;

            // Trigger Dodge Roll
            if (Input.GetKeyDown(KeyCode.LeftControl) || Input.GetKeyDown(KeyCode.C))
            {
                TryInitiateDodgeRoll(inputDir);
                return;
            }

            // Buffer Jump
            if (Input.GetButtonDown("Jump"))
            {
                jumpBufferTimer = jumpBufferDuration;
            }

            bool wantsSprint = Input.GetKey(KeyCode.LeftShift);
            bool isMoving = inputDir.sqrMagnitude > 0.01f;

            float currentSpeed = walkSpeed;

            if (isMoving)
            {
                // Smooth rotation towards camera forward
                float targetAngle = Mathf.Atan2(inputDir.x, inputDir.z) * Mathf.Rad2Deg;
                if (cameraTransform != null)
                {
                    targetAngle += cameraTransform.eulerAngles.y;
                }

                float angle = Mathf.SmoothDampAngle(transform.eulerAngles.y, targetAngle, ref currentTurnVelocity, rotationSmoothTime);
                transform.rotation = Quaternion.Euler(0f, angle, 0f);

                Vector3 moveDir = Quaternion.Euler(0f, targetAngle, 0f) * Vector3.forward;

                // Handle Sprinting with stamina consumption
                if (wantsSprint && staminaSystem != null && staminaSystem.TryConsumeStaminaOverTime(sprintStaminaCostPerSec, Time.deltaTime))
                {
                    currentSpeed = sprintSpeed;
                    SetState(MovementState.Sprinting);
                }
                else
                {
                    SetState(MovementState.Walking);
                }

                moveVelocity = moveDir.normalized * currentSpeed;
            }
            else
            {
                moveVelocity = Vector3.zero;
                if (isGrounded)
                {
                    SetState(MovementState.Idle);
                }
            }
        }

        private void HandleJumpAndGravity()
        {
            if (jumpBufferTimer > 0f && coyoteTimer > 0f)
            {
                if (staminaSystem == null || staminaSystem.TryConsumeStamina(jumpStaminaCost))
                {
                    verticalVelocity = Mathf.Sqrt(jumpHeight * -2f * gravity);
                    coyoteTimer = 0f;
                    jumpBufferTimer = 0f;
                    SetState(MovementState.Jumping);
                    OnJumped?.Invoke();
                }
            }

            verticalVelocity += gravity * Time.deltaTime;

            if (!isGrounded && verticalVelocity < 0f && currentState != MovementState.DodgeRolling)
            {
                SetState(MovementState.Falling);
            }
        }

        private void TryInitiateDodgeRoll(Vector3 inputDir)
        {
            if (isDodgeRolling || !isGrounded) return;

            if (staminaSystem != null && !staminaSystem.TryConsumeStamina(dodgeStaminaCost))
            {
                return;
            }

            if (inputDir.sqrMagnitude > 0.01f)
            {
                float targetAngle = Mathf.Atan2(inputDir.x, inputDir.z) * Mathf.Rad2Deg;
                if (cameraTransform != null) targetAngle += cameraTransform.eulerAngles.y;
                rollDirection = Quaternion.Euler(0f, targetAngle, 0f) * Vector3.forward;
                transform.rotation = Quaternion.Euler(0f, targetAngle, 0f);
            }
            else
            {
                rollDirection = transform.forward;
            }

            StartCoroutine(DodgeRollRoutine());
        }

        private IEnumerator DodgeRollRoutine()
        {
            isDodgeRolling = true;
            SetState(MovementState.DodgeRolling);
            OnDodgeRollStarted?.Invoke();

            float elapsed = 0f;
            while (elapsed < dodgeDuration)
            {
                Vector3 motion = (rollDirection * dodgeSpeed) + (Vector3.up * verticalVelocity);
                characterController.Move(motion * Time.deltaTime);

                verticalVelocity += gravity * Time.deltaTime;
                elapsed += Time.deltaTime;
                yield return null;
            }

            isDodgeRolling = false;
            SetState(isGrounded ? MovementState.Idle : MovementState.Falling);
        }

        private void HandleDodgeRollMovement()
        {
            // Handled deterministically in coroutine
        }

        public void ApplyKnockback(Vector3 forceVector)
        {
            knockbackVelocity += forceVector;
        }

        private void ApplyKnockbackDecay()
        {
            if (knockbackVelocity.sqrMagnitude > 0.01f)
            {
                characterController.Move(knockbackVelocity * Time.deltaTime);
                knockbackVelocity = Vector3.Lerp(knockbackVelocity, Vector3.zero, Time.deltaTime * 8f);
            }
            else
            {
                knockbackVelocity = Vector3.zero;
            }
        }

        private void ApplyFinalMovement()
        {
            Vector3 finalMotion = moveVelocity;
            finalMotion.y = verticalVelocity;
            characterController.Move(finalMotion * Time.deltaTime);
        }

        private void SetState(MovementState newState)
        {
            if (currentState == newState) return;
            currentState = newState;
            OnStateChanged?.Invoke(currentState);
        }
    }
}
