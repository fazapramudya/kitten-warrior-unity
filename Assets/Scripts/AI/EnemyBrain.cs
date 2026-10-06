using System;
using UnityEngine;
using UnityEngine.AI;
using KittenWarrior.Combat;

namespace KittenWarrior.AI
{
    public enum AIState
    {
        Idle,
        Patrol,
        Chase,
        Attack,
        Stagger,
        Dead
    }

    /// <summary>
    /// Modular finite state machine (FSM) enemy brain using NavMeshAgent.
    /// Handles sensory awareness, patrol waypoints, target engagement, and attack triggers.
    /// Owned by: Grimm (Enemy AI Architect)
    /// </summary>
    [RequireComponent(typeof(NavMeshAgent))]
    [DisallowMultipleComponent]
    public class EnemyBrain : MonoBehaviour
    {
        [Header("References")]
        [SerializeField] private EnemyBase enemyBase;
        [SerializeField] private NavMeshAgent agent;
        [SerializeField] private LayerMask targetLayer;
        [SerializeField] private LayerMask obstacleLayer;

        [Header("State Settings")]
        [SerializeField] private float idleDurationAtWaypoint = 2.5f;

        private AIState currentState = AIState.Idle;
        private Transform currentTarget;
        private Vector3 spawnPoint;
        private Vector3 patrolDestination;
        private float stateTimer;
        private float attackTimer;

        public AIState CurrentState => currentState;
        public Transform CurrentTarget => currentTarget;

        public event Action<AIState> OnAIStateChanged;
        public event Action OnPerformAttack;

        private void Awake()
        {
            if (agent == null) agent = GetComponent<NavMeshAgent>();
            if (enemyBase == null) enemyBase = GetComponent<EnemyBase>();
            spawnPoint = transform.position;
        }

        private void OnEnable()
        {
            if (enemyBase != null)
            {
                enemyBase.OnStaggerStarted += HandleStaggerStarted;
                enemyBase.OnStaggerEnded += HandleStaggerEnded;
                enemyBase.OnDeath += HandleDeath;
            }
        }

        private void OnDisable()
        {
            if (enemyBase != null)
            {
                enemyBase.OnStaggerStarted -= HandleStaggerStarted;
                enemyBase.OnStaggerEnded -= HandleStaggerEnded;
                enemyBase.OnDeath -= HandleDeath;
            }
        }

        private void Start()
        {
            if (enemyBase != null && enemyBase.Data != null)
            {
                agent.speed = enemyBase.Data.PatrolSpeed;
            }
            SetState(AIState.Patrol);
        }

        private void Update()
        {
            if (currentState == AIState.Dead || currentState == AIState.Stagger) return;

            if (attackTimer > 0f) attackTimer -= Time.deltaTime;

            LookForTarget();

            switch (currentState)
            {
                case AIState.Idle:
                    UpdateIdleState();
                    break;
                case AIState.Patrol:
                    UpdatePatrolState();
                    break;
                case AIState.Chase:
                    UpdateChaseState();
                    break;
                case AIState.Attack:
                    UpdateAttackState();
                    break;
            }
        }

        private void LookForTarget()
        {
            if (enemyBase == null || enemyBase.Data == null) return;

            // Search within sensory sphere
            Collider[] hits = Physics.OverlapSphere(transform.position, enemyBase.Data.DetectionRadius, targetLayer);
            if (hits.Length > 0)
            {
                Transform potential = hits[0].transform;
                Vector3 toTarget = (potential.position - transform.position).normalized;

                // Check Line of Sight
                if (!Physics.Raycast(transform.position + Vector3.up, toTarget, enemyBase.Data.DetectionRadius, obstacleLayer))
                {
                    currentTarget = potential;
                    if (currentState == AIState.Idle || currentState == AIState.Patrol)
                    {
                        SetState(AIState.Chase);
                    }
                }
            }
            else if (currentTarget != null && Vector3.Distance(transform.position, currentTarget.position) > enemyBase.Data.DetectionRadius * 1.5f)
            {
                // Lost target
                currentTarget = null;
                SetState(AIState.Patrol);
            }
        }

        private void UpdateIdleState()
        {
            stateTimer -= Time.deltaTime;
            if (stateTimer <= 0f)
            {
                SetState(AIState.Patrol);
            }
        }

        private void UpdatePatrolState()
        {
            if (enemyBase == null || enemyBase.Data == null) return;

            agent.speed = enemyBase.Data.PatrolSpeed;

            if (!agent.hasPath || agent.remainingDistance <= agent.stoppingDistance + 0.3f)
            {
                // Pick new random point around spawn
                Vector2 randomCircle = UnityEngine.Random.insideUnitCircle * enemyBase.Data.PatrolRadius;
                patrolDestination = spawnPoint + new Vector3(randomCircle.x, 0f, randomCircle.y);

                if (NavMesh.SamplePosition(patrolDestination, out NavMeshHit hit, 4f, NavMesh.AllAreas))
                {
                    agent.SetDestination(hit.position);
                    stateTimer = idleDurationAtWaypoint;
                    SetState(AIState.Idle);
                }
            }
        }

        private void UpdateChaseState()
        {
            if (currentTarget == null || enemyBase == null || enemyBase.Data == null)
            {
                SetState(AIState.Patrol);
                return;
            }

            agent.speed = enemyBase.Data.ChaseSpeed;
            agent.SetDestination(currentTarget.position);

            float distanceToTarget = Vector3.Distance(transform.position, currentTarget.position);
            if (distanceToTarget <= enemyBase.Data.AttackRange)
            {
                SetState(AIState.Attack);
            }
        }

        private void UpdateAttackState()
        {
            if (currentTarget == null || enemyBase == null || enemyBase.Data == null)
            {
                SetState(AIState.Patrol);
                return;
            }

            // Face target smoothly
            Vector3 lookDir = (currentTarget.position - transform.position).normalized;
            lookDir.y = 0f;
            if (lookDir != Vector3.zero)
            {
                transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(lookDir), Time.deltaTime * 8f);
            }

            float distanceToTarget = Vector3.Distance(transform.position, currentTarget.position);

            if (distanceToTarget > enemyBase.Data.AttackRange * 1.25f)
            {
                SetState(AIState.Chase);
                return;
            }

            if (attackTimer <= 0f)
            {
                attackTimer = enemyBase.Data.AttackCooldown;
                OnPerformAttack?.Invoke();
            }
        }

        private void HandleStaggerStarted()
        {
            agent.isStopped = true;
            SetState(AIState.Stagger);
        }

        private void HandleStaggerEnded()
        {
            agent.isStopped = false;
            SetState(currentTarget != null ? AIState.Chase : AIState.Patrol);
        }

        private void HandleDeath()
        {
            agent.isStopped = true;
            agent.enabled = false;
            SetState(AIState.Dead);
        }

        private void SetState(AIState newState)
        {
            if (currentState == newState) return;
            currentState = newState;
            OnAIStateChanged?.Invoke(currentState);
        }
    }
}
