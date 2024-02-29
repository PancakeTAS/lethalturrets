const GUN_OFFSET = 47.6; // Offset between the turret base and gun. This is required in order to rotate the turret around the point where it's held

const FOCUS_RADIUS = 33.0; // Amount of degrees the turret can focus on the player in
const MAX_ROTATION = 70.0; // Maximum amount of degrees the turret can rotate to the sides

const CLOCKWISE_SWITCH_TICKS = 210; // 7 seconds until turret rotates the other direction

const DETECTION_TICKS = 8; // 0.25 seconds until check for player
const DETECTION_RAND_TICKS = 5; // subtracted from detection ticks
const DETECTION_ROTATION_SPEED = 0.9333333333333333; // 28 degrees per second

const CHARGING_TICKS = 45; // 1.5 seconds until shoot
const CHARGING_ROTATION_SPEED = 3.1666666666666667; // 95 degrees per second

const TARGET_LOST_TICKS = 60; // 2 seconds until lose target (if shooting)

const NEXT_BULLET_TICKS = 6; // 0.2 seconds for bullet

/**
 * Create a turret entity
 *
 * @param {Vector} origin The origin of the turret
 */
function newTurret(origin) {
    return Turret()._create(origin);
}

/**
 * Lethal Company turret class
 *
 * @property {CBaseEntity} gun_ent The gun part of the turret
 * @property {CBaseEntity} holder_ent The gun holding part of the turret
 * @property {CBaseEntity} mount_ent The base mount of the turret
 * @property {number} turretAngle The angle of the turret
 * @property {number} currentRotation The current rotation of the turret
 * @property {number} targetRotation The target rotation of the turret
 * @property {number} rotationSpeed The speed of the turret rotation
 * @property {boolean} clockwiseRotation Whether the turret is rotating clockwise
 * @property {number} clockwiseSwitchTicks The ticks until the turret switches rotation direction
 * @property {number} detectionTicks The ticks until the turret checks for the player
 * @property {number} chargingTicks The ticks until the turret starts shooting
 * @property {number} currentState The current state of the turret
 * @property {number} targetLostTicks The ticks until the turret loses the target
 * @property {number} nextBulletTicks The ticks until the turret fires the next bullet
 */
class Turret {

    gun_ent = null;
    holder_ent = null;
    mount_ent = null;
    light_ent = null;

    // turret rotation
    turretAngle = 0;
    currentRotation = 0;
    targetRotation = 0;
    rotationSpeed = 0;

    // detection state
    clockwiseRotation = true;
    clockwiseSwitchTicks = 0;
    detectionTicks = 0;

    // charging state
    chargingTicks = 0;

    // firing state
    targetLostTicks = 0;
    nextBulletTicks = 0;

    currentState = 1; // 0 = deactivated, 1 = detection, 2 = charging, 3 = firing, 4 = berserk

    /**
     * Create a new turret
     *
     * @param {Vector} origin The origin of the turret
     *
     * @return A promise that resolves to the turret instance
     */
    function _create(origin) {
        local inst = this;

        return ppromise(async(function (resolve, reject):(origin, inst) {

            // create entities
            yield ppmod.create("turret/turret_gun.mdl");
            inst.gun_ent = yielded;
            inst.gun_ent.SetOrigin(origin + Vector(0, 0, GUN_OFFSET));
            this.gun_ent.SetAngles(0, -180, 0);

            yield ppmod.create("turret/turret_holder.mdl");
            inst.holder_ent = yielded;
            inst.holder_ent.SetOrigin(origin);
            this.holder_ent.SetAngles(0, -180, 0);

            yield ppmod.create("turret/turret_mount.mdl");
            inst.mount_ent = yielded;
            inst.mount_ent.SetOrigin(origin);
            this.mount_ent.SetAngles(0, -180, 0);

            yield ppmod.give("light_dynamic");
            inst.light_ent = yielded[0];
            inst.light_ent.SetOrigin(origin + Vector(-7.6, 1, 55));
            this.light_ent.SetAngles(0, 0, 0);
            inst.light_ent.Color("255 64 0");
            inst.light_ent.Brightness(5);
            inst.light_ent.Distance(64);

            // parent entities
            inst.gun_ent.SetMoveParent(inst.holder_ent);
            inst.holder_ent.SetMoveParent(inst.mount_ent);
            inst.light_ent.SetMoveParent(inst.gun_ent);
            inst.light_ent.TurnOff();

            resolve(inst);
        }));
    }

    /**
     * Check if the player is in range of the turret
     *
     * @param {boolean} aim Whether to aim at the player
     * @param {boolean} height Whether to check the height of the player
     */
    function checkPlayer(aim = false, height = true) {
        // TODO: constants

        // calculate angle to player
        local playerOrigin = GetPlayer().GetOrigin();
        local playerDelta = playerOrigin - this.mount_ent.GetOrigin();
        local playerAngle = (atan2(playerDelta.y, playerDelta.x) * 180/PI) - this.turretAngle - this.currentRotation;
        playerAngle = atan2(sin(playerAngle * PI/180), cos(playerAngle * PI/180)) * 180/PI;

        // check angle to player
        if (abs(playerAngle) >= FOCUS_RADIUS || playerAngle + this.currentRotation > MAX_ROTATION || playerAngle + this.currentRotation < -MAX_ROTATION)
            return false;

        // check distance to player < 500
        if (playerDelta.Length() > 500)
            return false;

        // check line of sight
        local trace = ppmod.ray(this.gun_ent.GetOrigin(), playerOrigin);
        if (trace.fraction < 1)
            return false;

        // check if player is on same height level
        if (height && abs(playerDelta.z) > 72)
            return false;

        // aim at player
        if (aim)
            this.targetRotation = max(-MAX_ROTATION, min(MAX_ROTATION, playerAngle + this.currentRotation));

        return true;
    }

    /**
     * Tick the turret
     */
    function tick() {
        switch (this.currentState) {
            case 0: // TODO: deactivated
                break;
            case 1: // detection
                // update variables
                this.rotationSpeed = DETECTION_ROTATION_SPEED * 3.3;
                this.chargingTicks = 0;
                this.targetLostTicks = 0;
                this.nextBulletTicks = 0;

                // check for player
                if (this.detectionTicks++ >= DETECTION_TICKS) {
                    this.detectionTicks = RandomInt(0, DETECTION_RAND_TICKS);
                    if (this.checkPlayer()) {
                        this.gun_ent.EmitSound("LethalTurrets.SeePlayer");
                        this.light_ent.TurnOn();

                        this.currentState = 2;
                        printl("Switching to charging");
                    }
                }

                // rotate the turret
                if (this.clockwiseSwitchTicks++ >= CLOCKWISE_SWITCH_TICKS) {
                    this.clockwiseSwitchTicks = 0;
                    this.clockwiseRotation = !this.clockwiseRotation;
                }

                this.targetRotation = max(-MAX_ROTATION, min(MAX_ROTATION, this.targetRotation + (this.clockwiseRotation ? rotationSpeed : -rotationSpeed)));
                break;
            case 2: // charging
                // update variables
                this.rotationSpeed = CHARGING_ROTATION_SPEED;
                this.detectionTicks = 0;
                this.clockwiseSwitchTicks = 0;
                this.targetLostTicks = 0;
                this.nextBulletTicks = 0;

                // check for player
                if (this.checkPlayer(true, false)) {
                    // check if focused for long enough
                    if (this.chargingTicks++ >= CHARGING_TICKS) {
                        this.gun_ent.EmitSound("LethalTurrets.Fire");
                        this.light_ent.TurnOn();

                        this.currentState = 3;
                        printl("Switching to firing");
                    }
                } else {
                    this.light_ent.TurnOff();

                    this.currentState = 1;
                    printl("Switching to detection");
                }
                break;
            case 3: // firing
                // update variables
                this.rotationSpeed = CHARGING_ROTATION_SPEED;
                this.detectionTicks = 0;
                this.chargingTicks = 0;
                this.clockwiseSwitchTicks = 0;

                // check if lost target for too long
                if (!this.checkPlayer(true, false))
                    if (this.targetLostTicks++ >= TARGET_LOST_TICKS) {
                        this.light_ent.TurnOff();

                        this.currentState = 1;
                        printl("Switching to detection");
                    }

                // check if should fire bullet
                if (this.nextBulletTicks++ >= NEXT_BULLET_TICKS) {
                    this.nextBulletTicks = 0;
                    print("F");
                }
                break;
            case 4: // TODO: berserk
                break;
        }

        // rotate the turret
        local deltaRotation = max(-rotationSpeed, min(rotationSpeed, this.targetRotation - this.currentRotation));
        this.currentRotation += deltaRotation;
        this.holder_ent.angles = "0 " + (this.currentRotation + this.turretAngle - 180) + " 0";
    }

    /**
     * Set the base angle of the turret
     *
     * @param {number} turretAngle The new angle in degrees of the turret
     */
    function rotate(turretAngle) {
        this.turretAngle = turretAngle;
        this.mount_ent.angles = "0 " + (turretAngle - 180) + " 0";
    }

}
