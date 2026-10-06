using System;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace KittenWarrior.Core
{
    public enum GameState
    {
        Boot,
        InGame,
        Paused,
        GameOver
    }

    /// <summary>
    /// Central game manager coordinating high-level states, timescale, and cursor locks.
    /// Owned by: Luna (Systems & Tech Lead)
    /// </summary>
    [DisallowMultipleComponent]
    public class GameManager : MonoBehaviour
    {
        public static GameManager Instance { get; private set; }

        [Header("State")]
        [SerializeField] private GameState currentState = GameState.Boot;

        [Header("Target Frame Rate")]
        [SerializeField] private int targetFrameRate = 120;

        public GameState CurrentState => currentState;

        public event Action<GameState> OnGameStateChanged;

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }

            Instance = this;
            DontDestroyOnLoad(gameObject);

            Application.targetFrameRate = targetFrameRate;
        }

        private void Start()
        {
            SetGameState(GameState.InGame);
        }

        private void Update()
        {
            if (Input.GetKeyDown(KeyCode.Escape))
            {
                if (currentState == GameState.InGame)
                {
                    PauseGame();
                }
                else if (currentState == GameState.Paused)
                {
                    ResumeGame();
                }
            }
        }

        public void SetGameState(GameState newState)
        {
            if (currentState == newState) return;
            currentState = newState;

            switch (currentState)
            {
                case GameState.InGame:
                    Time.timeScale = 1f;
                    Cursor.lockState = CursorLockMode.Locked;
                    Cursor.visible = false;
                    break;
                case GameState.Paused:
                    Time.timeScale = 0f;
                    Cursor.lockState = CursorLockMode.None;
                    Cursor.visible = true;
                    break;
                case GameState.GameOver:
                    Cursor.lockState = CursorLockMode.None;
                    Cursor.visible = true;
                    break;
            }

            OnGameStateChanged?.Invoke(currentState);
        }

        public void PauseGame() => SetGameState(GameState.Paused);
        public void ResumeGame() => SetGameState(GameState.InGame);

        public void RestartCurrentScene()
        {
            Time.timeScale = 1f;
            Scene current = SceneManager.GetActiveScene();
            SceneManager.LoadScene(current.buildIndex);
            SetGameState(GameState.InGame);
        }
    }
}
