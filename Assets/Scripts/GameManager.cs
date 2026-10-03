using UnityEngine;
using UnityEngine.SceneManagement;

/// <summary>
/// Zählt Münzen, misst die Zeit und zeigt alles auf dem Bildschirm an.
/// Sind alle Münzen eingesammelt, ist das Level gewonnen. R startet neu.
/// </summary>
public class GameManager : MonoBehaviour
{
    public static GameManager Instance { get; private set; }

    private int totalCoins;
    private int collectedCoins;
    private int hits;
    private float startTime;
    private float finishTime;
    private bool won;

    private GUIStyle style;
    private GUIStyle bigStyle;

    void Awake()
    {
        Instance = this;
        startTime = Time.time;
    }

    void Update()
    {
        if (Input.GetKeyDown(KeyCode.R))
            SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex);
    }

    public void RegisterCoin()
    {
        totalCoins++;
    }

    public void CollectCoin()
    {
        collectedCoins++;
        if (!won && collectedCoins >= totalCoins)
        {
            won = true;
            finishTime = Time.time - startTime;
        }
    }

    public void PlayerHit()
    {
        hits++;
    }

    // OnGUI ist die einfachste Art, Text anzuzeigen – ganz ohne Canvas oder Zusatzpakete.
    void OnGUI()
    {
        if (style == null)
        {
            style = new GUIStyle(GUI.skin.label) { fontSize = 22, fontStyle = FontStyle.Bold };
            style.normal.textColor = Color.white;
            bigStyle = new GUIStyle(style) { fontSize = 44, alignment = TextAnchor.MiddleCenter };
            bigStyle.normal.textColor = Color.yellow;
        }

        float time = won ? finishTime : Time.time - startTime;
        GUI.Label(new Rect(20, 20, 400, 30), $"Münzen: {collectedCoins} / {totalCoins}", style);
        GUI.Label(new Rect(20, 50, 400, 30), $"Zeit: {time:0.0} s", style);
        GUI.Label(new Rect(20, 80, 400, 30), $"Getroffen: {hits}", style);

        GUI.Label(new Rect(20, Screen.height - 40, 900, 30),
            "WASD laufen · Shift rennen · Leertaste springen · Maus Kamera · R Neustart · Esc Maus frei",
            style);

        if (won)
        {
            GUI.Label(new Rect(0, Screen.height / 2f - 60, Screen.width, 120),
                $"Gewonnen! Zeit: {finishTime:0.0} s\nDrück R für eine neue Runde", bigStyle);
        }
    }
}
