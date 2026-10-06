using UnityEngine;

namespace KittenWarrior.Core
{
    /// <summary>
    /// Controls atmospheric environment lighting inspired by Valheim's golden-hour aesthetics.
    /// Manages Directional Sun Light warmth, ambient color gradients, and linear/volumetric fog density.
    /// Owned by: Luna (Systems & Tech Lead)
    /// </summary>
    [ExecuteAlways]
    [DisallowMultipleComponent]
    public class AtmosphericLightingController : MonoBehaviour
    {
        [Header("Sun / Directional Light")]
        [SerializeField] private Light directionalSun;
        [SerializeField] private Color goldenHourSunColor = new Color(1.0f, 0.76f, 0.48f, 1f);
        [SerializeField] private float sunIntensity = 1.35f;

        [Header("Ambient Sky Gradients")]
        [SerializeField] private Color ambientSkyColor = new Color(0.48f, 0.62f, 0.85f, 1f);
        [SerializeField] private Color ambientEquatorColor = new Color(0.68f, 0.55f, 0.45f, 1f);
        [SerializeField] private Color ambientGroundColor = new Color(0.25f, 0.22f, 0.18f, 1f);

        [Header("Fog Configuration (Valheim Style)")]
        [SerializeField] private bool enableFog = true;
        [SerializeField] private Color atmosphericFogColor = new Color(0.72f, 0.68f, 0.62f, 1f);
        [SerializeField] private FogMode fogMode = FogMode.ExponentialSquared;
        [SerializeField] private float fogDensity = 0.015f;

        private void Start()
        {
            ApplyAtmosphere();
        }

        private void OnValidate()
        {
            ApplyAtmosphere();
        }

        public void ApplyAtmosphere()
        {
            // Apply Sun Light Settings
            if (directionalSun != null)
            {
                directionalSun.color = goldenHourSunColor;
                directionalSun.intensity = sunIntensity;
                directionalSun.shadows = LightShadows.Soft;
            }

            // Apply Ambient Trilight Settings
            RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Trilight;
            RenderSettings.ambientSkyColor = ambientSkyColor;
            RenderSettings.ambientEquatorColor = ambientEquatorColor;
            RenderSettings.ambientGroundColor = ambientGroundColor;

            // Apply Fog Settings
            RenderSettings.fog = enableFog;
            if (enableFog)
            {
                RenderSettings.fogColor = atmosphericFogColor;
                RenderSettings.fogMode = fogMode;
                RenderSettings.fogDensity = fogDensity;
            }
        }
    }
}
