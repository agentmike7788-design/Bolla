using UnityEngine;

/// <summary>
/// Steuert die Spielfigur: Laufen (WASD), Rennen (Shift), Springen (Leertaste).
/// Die Laufrichtung richtet sich nach der Blickrichtung der Kamera.
/// </summary>
[RequireComponent(typeof(CharacterController))]
public class PlayerController : MonoBehaviour
{
    // Damit andere Skripte (z.B. Gegner) die Spielfigur einfach finden.
    public static PlayerController Current { get; private set; }

    [Header("Bewegung")]
    public float walkSpeed = 5f;
    public float sprintSpeed = 9f;
    public float turnSpeed = 720f;      // Grad pro Sekunde

    [Header("Springen")]
    public float jumpHeight = 1.6f;
    public float gravity = -20f;

    [Header("Respawn")]
    public float fallLimitY = -10f;     // fällt man tiefer, startet man neu

    private CharacterController controller;
    private Transform cam;
    private float verticalVelocity;
    private Vector3 spawnPosition;
    private Quaternion spawnRotation;

    void Awake()
    {
        Current = this;
        controller = GetComponent<CharacterController>();
    }

    void Start()
    {
        if (Camera.main != null)
            cam = Camera.main.transform;

        spawnPosition = transform.position;
        spawnRotation = transform.rotation;
    }

    void Update()
    {
        // 1. Eingabe lesen
        float x = Input.GetAxisRaw("Horizontal");
        float z = Input.GetAxisRaw("Vertical");
        Vector3 input = Vector3.ClampMagnitude(new Vector3(x, 0f, z), 1f);

        // 2. Eingabe relativ zur Kamera umrechnen
        Vector3 move = input;
        if (cam != null)
        {
            Vector3 forward = Vector3.ProjectOnPlane(cam.forward, Vector3.up).normalized;
            Vector3 right = Vector3.ProjectOnPlane(cam.right, Vector3.up).normalized;
            move = forward * input.z + right * input.x;
        }

        // 3. Figur in Laufrichtung drehen
        if (move.sqrMagnitude > 0.01f)
        {
            Quaternion targetRotation = Quaternion.LookRotation(move);
            transform.rotation = Quaternion.RotateTowards(
                transform.rotation, targetRotation, turnSpeed * Time.deltaTime);
        }

        // 4. Schwerkraft und Springen
        if (controller.isGrounded && verticalVelocity < 0f)
            verticalVelocity = -2f; // hält die Figur am Boden

        if (controller.isGrounded && Input.GetButtonDown("Jump"))
            verticalVelocity = Mathf.Sqrt(jumpHeight * -2f * gravity);

        verticalVelocity += gravity * Time.deltaTime;

        // 5. Bewegen
        float speed = Input.GetKey(KeyCode.LeftShift) ? sprintSpeed : walkSpeed;
        Vector3 velocity = move * speed + Vector3.up * verticalVelocity;
        controller.Move(velocity * Time.deltaTime);

        // 6. Heruntergefallen?
        if (transform.position.y < fallLimitY)
            Respawn();
    }

    /// <summary>Setzt die Figur an den Startpunkt zurück.</summary>
    public void Respawn()
    {
        // Der CharacterController muss kurz aus sein, sonst ignoriert er die neue Position.
        controller.enabled = false;
        transform.SetPositionAndRotation(spawnPosition, spawnRotation);
        controller.enabled = true;
        verticalVelocity = 0f;
    }
}
