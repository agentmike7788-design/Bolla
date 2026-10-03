using UnityEngine;

/// <summary>
/// Eine Münze zum Einsammeln. Dreht sich und schwebt leicht auf und ab.
/// Braucht einen Collider mit "Is Trigger" = an.
/// </summary>
public class Collectible : MonoBehaviour
{
    public float spinSpeed = 120f;
    public float bobHeight = 0.25f;
    public float bobSpeed = 2f;

    private Vector3 startPosition;

    void Start()
    {
        startPosition = transform.position;
        if (GameManager.Instance != null)
            GameManager.Instance.RegisterCoin();
    }

    void Update()
    {
        transform.Rotate(0f, spinSpeed * Time.deltaTime, 0f, Space.World);
        float offset = Mathf.Sin(Time.time * bobSpeed) * bobHeight;
        transform.position = startPosition + Vector3.up * offset;
    }

    void OnTriggerEnter(Collider other)
    {
        if (other.GetComponent<PlayerController>() == null)
            return;

        if (GameManager.Instance != null)
            GameManager.Instance.CollectCoin();

        Destroy(gameObject);
    }
}
