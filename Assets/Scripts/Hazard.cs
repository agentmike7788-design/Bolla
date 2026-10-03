using UnityEngine;

/// <summary>
/// Ein Gegner, der hin- und herfährt. Berührt er die Spielfigur,
/// muss sie zurück zum Start.
/// </summary>
public class Hazard : MonoBehaviour
{
    public Vector3 moveOffset = new Vector3(6f, 0f, 0f); // wie weit er fährt
    public float speed = 1f;                              // Hin-und-her pro Sekunde (ungefähr)
    public float hitRadius = 1.3f;                        // Abstand, ab dem er trifft

    private Vector3 startPosition;

    void Start()
    {
        startPosition = transform.position;
    }

    void Update()
    {
        // PingPong läuft von 0 bis 1 und wieder zurück
        float t = Mathf.PingPong(Time.time * speed, 1f);
        transform.position = startPosition + moveOffset * t;

        PlayerController player = PlayerController.Current;
        if (player == null)
            return;

        float sqrDistance = (player.transform.position - transform.position).sqrMagnitude;
        if (sqrDistance < hitRadius * hitRadius)
        {
            player.Respawn();
            if (GameManager.Instance != null)
                GameManager.Instance.PlayerHit();
        }
    }
}
