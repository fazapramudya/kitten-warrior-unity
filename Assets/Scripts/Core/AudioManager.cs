using System;
using UnityEngine;

namespace KittenWarrior.Core
{
    [Serializable]
    public struct SoundEffect
    {
        public string Name;
        public AudioClip Clip;
        [Range(0f, 1f)] public float Volume;
        [Range(0.5f, 1.5f)] public float PitchVariation;
    }

    /// <summary>
    /// Audio manager providing zero-allocation one-shot playback for sword swings, impacts, parries, and ambience.
    /// Owned by: Luna (Systems & Tech Lead)
    /// </summary>
    [DisallowMultipleComponent]
    public class AudioManager : MonoBehaviour
    {
        public static AudioManager Instance { get; private set; }

        [Header("Audio Sources")]
        [SerializeField] private AudioSource sfxSource;
        [SerializeField] private AudioSource musicSource;

        [Header("SFX Library")]
        [SerializeField] private SoundEffect[] sfxClips;

        private void Awake()
        {
            if (Instance != null && Instance != this)
            {
                Destroy(gameObject);
                return;
            }

            Instance = this;

            if (sfxSource == null)
            {
                sfxSource = gameObject.AddComponent<AudioSource>();
            }

            if (musicSource == null)
            {
                musicSource = gameObject.AddComponent<AudioSource>();
                musicSource.loop = true;
            }
        }

        public void PlaySFX(string soundName)
        {
            if (sfxClips == null || sfxSource == null) return;

            for (int i = 0; i < sfxClips.Length; i++)
            {
                if (sfxClips[i].Name.Equals(soundName, StringComparison.OrdinalIgnoreCase))
                {
                    float basePitch = 1f;
                    float variation = sfxClips[i].PitchVariation > 0 ? UnityEngine.Random.Range(-sfxClips[i].PitchVariation, sfxClips[i].PitchVariation) : 0f;
                    sfxSource.pitch = Mathf.Clamp(basePitch + variation, 0.7f, 1.3f);
                    sfxSource.PlayOneShot(sfxClips[i].Clip, sfxClips[i].Volume);
                    return;
                }
            }
        }

        public void PlayMusic(AudioClip musicClip, float volume = 0.6f)
        {
            if (musicSource == null || musicClip == null) return;
            musicSource.clip = musicClip;
            musicSource.volume = volume;
            musicSource.Play();
        }
    }
}
