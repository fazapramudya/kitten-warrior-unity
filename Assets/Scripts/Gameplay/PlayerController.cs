using System;
using System.Collections;
using UnityEngine;

namespace KittenWarrior.Gameplay
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
    /// Responsive 3D third-person character locomotion controller.
    /// Handles camera-relative movement, feline agility, jumping, and dodge-rolling.
    /// Owned by: Felix (Gameplay Lead)
    /// </summary>
    [RequireComponent(typeof(CharacterController))]
    [DisallowMultipleComponent]
    public class PlayerController : MonoBehaviour
    {
        [Header("Locomotion Speeds")]
        [SerializeField] private float walkSpeed = 4.5f;
        [SerializeField] private float sprintSpeed = 7.5f;
        [SerializeField] private float rotationSmoothTime = 0.08f;

        [Header("Jump & Gravity")]
        [SerializeField] private float jumpHeight = 1.4f;
        [SerializeField] private float gravity = -20f;
        [SerializeField] private float coyoteTimeDuration = 0.15f;
        [SerializeField] private float jumpBufferDuration = 0.15f;

        [Header("Dodge Roll Settings")]
        [SerializeField] private float dodgeSpeed = 10.5f;
        [SerializeField] private float dodgeDuration = 0.38f;
        [SerializeField] private float dodgeStaminaCost = 25f;
        [SerializeField] private float sprintStaminaCostPerSec = 14f;
        [SerializeField] private float jumpStaminaCost = 15f;

        [Header("References")]
        [SerializeField] private Transform cameraTransform;
        [SerializeField] private StaminaSystem staminaSystem;

        private CharacterController characterController;
        private MovementState currentState = MovementState.Idle;

        private Vector3 velocity;
        private float verticalVelocity;
        private float currentTurnVelocity;
        private float coyoteTimer;
        private float jumpBufferTimer;
        private bool isGrounded;
        private bool isDodgeRolling;
        private Vector3 rollDirection;

        public MovementState CurrentState => currentState;
        public bool IsGrounded => isGrounded;
        public Vector3 Velocity => characterController.velocity;

        public event Action<MovementState> OnStateChanged;
        public event Action OnJumped;
        public event Action OnDodgeRollStarted;

        private void Awake()
        {
            characterController = GetComponent<CharacterController>();
            if (staminaSystem == null)
            {
                staminaSystem = GetComponent<StaminaSystem>();
            }

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

            ReadInputAndMove();
            HandleJumpAndGravity();
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
                    // Small negative stick force to keep grounded on slopes
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

        private void ReadInputAndMove()
        {
            float horizontal = Input.GetAxisRaw("Horizontal");
            float vertical = Input.GetAxisRaw("Vertical");
            Vector3 inputDir = new Vector3(horizontal, 0f, vertical).normalized;

            // Trigger Dodge Roll (Space or Left Alt or customizable)
            if (Input.GetKeyDown(KeyCode.LeftControl) || Input.GetKeyDown(KeyCode.C))
            {
                TryInitiateDodgeRoll(inputDir);
                return;
            }

            // Buffer Jump input
            if (Input.GetButtonDown("Jump"))
            {
                jumpBufferTimer = jumpBufferDuration;
            }

            bool wantsSprint = Input.GetKey(KeyCode.LeftShift);
            bool isMoving = inputDir.sqrMagnitude > 0.01f;

            float currentSpeed = walkSpeed;

            if (isMoving)
            {
                // Calculate camera-relative movement angle
                float targetAngle = Mathf.Atan2(inputDir.x, inputDir.z) * Mathf.Rad2Deg;
                if (cameraTransform != null)
                {
                    targetAngle += cameraTransform.eulerAngles.y;
                }

                float angle = Mathf.SmoothDampAngle(transform.eulerAngles.y, targetAngle, ref currentTurnVelocity, rotationSmoothTime);
                transform.rotation = Quaternion.Euler(0f, angle, 0f);

                Vector3 moveDir = Quaternion.Euler(0f, targetAngle, 0f) * Vector3.forward;

                // Handle Sprinting with stamina drain
                if (wantsSprint && staminaSystem != null && staminaSystem.TryConsumeStaminaOverTime(sprintStaminaCostPerSec, Time.deltaTime))
                {
                    currentSpeed = sprintSpeed;
                    SetState(MovementState.Sprinting);
                }
                else
                {
                    SetState(MovementState.Walking);
                }

                velocity = moveDir.normalized * currentSpeed;
            }
            else
            {
                velocity = Vector3.zero;
                if (isGrounded)
                {
                    SetState(MovementState.Idle);
                }
            }
        }

        private void HandleJumpAndGravity()
        {
            // Execute buffered jump if coyote time is valid
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

            // Apply gravity
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
                return; // Not enough stamina
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
            // Handled inside coroutine for deterministic duration
        }

        private void ApplyFinalMovement()
        {
            Vector3 finalMotion = velocity;
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
