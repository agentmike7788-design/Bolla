using System.Collections.Generic;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

/// <summary>
/// Fügt im Unity-Editor den Menüpunkt "Spiel > Demo-Level erstellen" hinzu.
/// Ein Klick baut ein spielbares Level: Boden, Plattformen, Spielfigur,
/// Kamera, Münzen und Gegner. Die Szene wird unter Assets/Scenes gespeichert.
/// </summary>
public static class DemoLevelBuilder
{
    private const string ScenePath = "Assets/Scenes/DemoLevel.unity";
    private const string MaterialFolder = "Assets/Materials";

    [MenuItem("Spiel/Demo-Level erstellen")]
    public static void BuildDemoLevel()
    {
        // Ungespeicherte Änderungen nicht einfach verwerfen
        if (!EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())
            return;

        var scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);

        Material groundMat = GetMaterial("Boden", new Color(0.35f, 0.6f, 0.35f));
        Material platformMat = GetMaterial("Plattform", new Color(0.55f, 0.55f, 0.6f));
        Material playerMat = GetMaterial("Spieler", new Color(0.2f, 0.45f, 0.9f));
        Material coinMat = GetMaterial("Muenze", new Color(1f, 0.8f, 0.1f));
        Material hazardMat = GetMaterial("Gegner", new Color(0.9f, 0.15f, 0.15f));

        // --- Boden ---
        GameObject ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
        ground.name = "Boden";
        ground.transform.localScale = new Vector3(5f, 1f, 5f); // 50 x 50 Meter
        SetMaterial(ground, groundMat);

        // --- Plattformen (eine Treppe zum Hochspringen) ---
        var level = new GameObject("Level").transform;
        CreatePlatform(level, new Vector3(6f, 0.5f, 6f), new Vector3(3f, 1f, 3f), platformMat);
        CreatePlatform(level, new Vector3(10f, 1f, 9f), new Vector3(3f, 2f, 3f), platformMat);
        CreatePlatform(level, new Vector3(14f, 1.5f, 12f), new Vector3(3f, 3f, 3f), platformMat);
        CreatePlatform(level, new Vector3(-10f, 0.5f, 10f), new Vector3(6f, 1f, 2f), platformMat);
        CreatePlatform(level, new Vector3(-14f, 0.5f, -12f), new Vector3(4f, 1f, 4f), platformMat);

        // --- Spielfigur ---
        GameObject player = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        player.name = "Spieler";
        player.transform.position = new Vector3(0f, 1.1f, -6f);
        Object.DestroyImmediate(player.GetComponent<CapsuleCollider>()); // der CharacterController hat einen eigenen
        player.AddComponent<CharacterController>();
        player.AddComponent<PlayerController>();
        SetMaterial(player, playerMat);

        // Kleine "Nase", damit man sieht, wohin die Figur schaut
        GameObject nose = GameObject.CreatePrimitive(PrimitiveType.Cube);
        nose.name = "Nase";
        Object.DestroyImmediate(nose.GetComponent<BoxCollider>());
        nose.transform.SetParent(player.transform, false);
        nose.transform.localPosition = new Vector3(0f, 0.5f, 0.5f);
        nose.transform.localScale = new Vector3(0.3f, 0.2f, 0.3f);
        SetMaterial(nose, hazardMat);

        // --- Kamera ---
        Camera cam = Camera.main;
        if (cam == null)
        {
            cam = new GameObject("Main Camera").AddComponent<Camera>();
            cam.tag = "MainCamera";
        }
        cam.transform.position = player.transform.position + new Vector3(0f, 3f, -6f);
        cam.transform.rotation = Quaternion.Euler(15f, 0f, 0f);
        var follow = cam.gameObject.AddComponent<ThirdPersonCamera>();
        follow.target = player.transform;

        // --- Spielleitung (Punkte, Zeit, Anzeige) ---
        new GameObject("GameManager").AddComponent<GameManager>();

        // --- Münzen ---
        var coins = new GameObject("Muenzen").transform;
        var coinPositions = new List<Vector3>
        {
            new Vector3(0f, 1f, 0f),
            new Vector3(3f, 1f, 3f),
            new Vector3(-4f, 1f, 4f),
            new Vector3(6f, 2f, 6f),     // auf Plattform 1
            new Vector3(10f, 3f, 9f),    // auf Plattform 2
            new Vector3(14f, 4f, 12f),   // auf Plattform 3
            new Vector3(-10f, 2f, 10f),  // auf der langen Plattform
            new Vector3(-14f, 2f, -12f),
            new Vector3(12f, 1f, -10f),
            new Vector3(-6f, 1f, -14f),
        };
        foreach (Vector3 pos in coinPositions)
            CreateCoin(coins, pos, coinMat);

        // --- Gegner ---
        var hazards = new GameObject("Gegner").transform;
        CreateHazard(hazards, new Vector3(-7f, 0.75f, 2f), new Vector3(9f, 0f, 0f), 0.4f, hazardMat);
        CreateHazard(hazards, new Vector3(9f, 0.75f, -14f), new Vector3(0f, 0f, 8f), 0.3f, hazardMat);
        CreateHazard(hazards, new Vector3(-12f, 0.75f, -4f), new Vector3(6f, 0f, -6f), 0.25f, hazardMat);

        // --- Speichern und zu den Build Settings hinzufügen ---
        EnsureFolder("Assets/Scenes");
        EditorSceneManager.SaveScene(scene, ScenePath);
        AddSceneToBuildSettings(ScenePath);

        Selection.activeGameObject = player;
        Debug.Log("Demo-Level erstellt und gespeichert unter " + ScenePath + ". Drück oben auf Play!");
    }

    private static void CreatePlatform(Transform parent, Vector3 position, Vector3 size, Material mat)
    {
        GameObject platform = GameObject.CreatePrimitive(PrimitiveType.Cube);
        platform.name = "Plattform";
        platform.transform.SetParent(parent, false);
        platform.transform.position = position;
        platform.transform.localScale = size;
        SetMaterial(platform, mat);
    }

    private static void CreateCoin(Transform parent, Vector3 position, Material mat)
    {
        // Das Elternobjekt trägt Skript und Trigger, das Kind ist nur die Optik.
        var coin = new GameObject("Muenze");
        coin.transform.SetParent(parent, false);
        coin.transform.position = position;
        var trigger = coin.AddComponent<SphereCollider>();
        trigger.isTrigger = true;
        trigger.radius = 0.7f;
        coin.AddComponent<Collectible>();

        GameObject visual = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        visual.name = "Optik";
        Object.DestroyImmediate(visual.GetComponent<CapsuleCollider>());
        visual.transform.SetParent(coin.transform, false);
        visual.transform.localRotation = Quaternion.Euler(90f, 0f, 0f);
        visual.transform.localScale = new Vector3(0.8f, 0.05f, 0.8f);
        SetMaterial(visual, mat);
    }

    private static void CreateHazard(Transform parent, Vector3 position, Vector3 offset, float speed, Material mat)
    {
        GameObject hazard = GameObject.CreatePrimitive(PrimitiveType.Cube);
        hazard.name = "Gegner";
        Object.DestroyImmediate(hazard.GetComponent<BoxCollider>()); // trifft per Abstand, nicht per Kollision
        hazard.transform.SetParent(parent, false);
        hazard.transform.position = position;
        hazard.transform.localScale = new Vector3(1.5f, 1.5f, 1.5f);
        var h = hazard.AddComponent<Hazard>();
        h.moveOffset = offset;
        h.speed = speed;
        SetMaterial(hazard, mat);
    }

    private static void SetMaterial(GameObject go, Material mat)
    {
        go.GetComponent<Renderer>().sharedMaterial = mat;
    }

    /// <summary>Lädt ein Material aus Assets/Materials oder legt es neu an.</summary>
    private static Material GetMaterial(string name, Color color)
    {
        string path = MaterialFolder + "/" + name + ".mat";
        var mat = AssetDatabase.LoadAssetAtPath<Material>(path);
        if (mat != null)
            return mat;

        // URP-Projekte brauchen den URP-Shader, ältere Projekte den Standard-Shader
        Shader shader = Shader.Find("Universal Render Pipeline/Lit");
        if (shader == null)
            shader = Shader.Find("Standard");

        EnsureFolder(MaterialFolder);
        mat = new Material(shader) { color = color };
        AssetDatabase.CreateAsset(mat, path);
        return mat;
    }

    private static void EnsureFolder(string folder)
    {
        if (!AssetDatabase.IsValidFolder(folder))
            AssetDatabase.CreateFolder("Assets", folder.Substring("Assets/".Length));
    }

    private static void AddSceneToBuildSettings(string path)
    {
        var scenes = new List<EditorBuildSettingsScene>(EditorBuildSettings.scenes);
        // Unsere Szene soll die erste sein (Index 0)
        scenes.RemoveAll(s => s.path == path);
        scenes.Insert(0, new EditorBuildSettingsScene(path, true));
        EditorBuildSettings.scenes = scenes.ToArray();
    }
}
