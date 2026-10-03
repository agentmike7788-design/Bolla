using UnityEngine;

/// <summary>
/// Kamera, die der Spielfigur von hinten folgt und sich mit der Maus drehen lässt.
/// Escape gibt die Maus frei, ein Linksklick fängt sie wieder ein.
/// </summary>
public class ThirdPersonCamera : MonoBehaviour
{
    public Transform target;            // die Spielfigur

    [Header("Abstand")]
    public float distance = 6f;
    public float pivotHeight = 1.5f;    // Höhe über der Figur, um die gedreht wird

    [Header("Maus")]
    public float mouseSensitivity = 3f;
    public float minPitch = -30f;
    public float maxPitch = 70f;

    [Header("Kollision")]
    public float collisionRadius = 0.3f; // verhindert, dass die Kamera in Wände rutscht

    private float yaw;
    private float pitch = 15f;

    void Start()
    {
        yaw = transform.eulerAngles.y;
        LockCursor(true);
    }

    void LateUpdate()
    {
        if (target == null)
            return;

        // Maus ein-/ausfangen
        if (Input.GetKeyDown(KeyCode.Escape))
            LockCursor(false);
        else if (Input.GetMouseButtonDown(0))
            LockCursor(true);

        // Drehen nur, wenn die Maus gefangen ist
        if (Cursor.lockState == CursorLockMode.Locked)
        {
            yaw += Input.GetAxis("Mouse X") * mouseSensitivity;
            pitch -= Input.GetAxis("Mouse Y") * mouseSensitivity;
            pitch = Mathf.Clamp(pitch, minPitch, maxPitch);
        }

        Quaternion rotation = Quaternion.Euler(pitch, yaw, 0f);
        Vector3 pivot = target.position + Vector3.up * pivotHeight;
        Vector3 direction = rotation * Vector3.back;

        // Wenn etwas zwischen Figur und Kamera ist, Kamera näher heranholen
        float currentDistance = distance;
        if (Physics.SphereCast(pivot, collisionRadius, direction, out RaycastHit hit,
                distance, ~0, QueryTriggerInteraction.Ignore))
        {
            currentDistance = hit.distance;
        }

        transform.SetPositionAndRotation(pivot + direction * currentDistance, rotation);
    }

    private static void LockCursor(bool locked)
    {
        Cursor.lockState = locked ? CursorLockMode.Locked : CursorLockMode.None;
        Cursor.visible = !locked;
    }
}
