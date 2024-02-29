const GUN_OFFSET = 47.6; // Offset between the turret base and gun. This is required in order to rotate the turret around the point where it's held

const FOCUS_RADIUS = 33.0; // Amount of degrees the turret can focus on the player in
const FOCUS_DISTANCE = 512.0; // Maximum distance the turret can focus on the player
const FOCUS_HEIGHT = 72.0; // Maximum height difference the turret can focus on the player
const MAX_ROTATION = 70.0; // Maximum amount of degrees the turret can rotate to the sides

const CLOCKWISE_SWITCH_TICKS = 210; // 7 seconds until turret rotates the other direction

const DETECTION_TICKS = 8; // 0.25 seconds until check for player
const DETECTION_RAND_TICKS = 5; // subtracted from detection ticks
const DETECTION_ROTATION_SPEED = 0.9333333333333333; // 28 degrees per second

const CHARGING_TICKS = 45; // 1.5 seconds until shoot
const CHARGING_ROTATION_SPEED = 3.1666666666666667; // 95 degrees per second

const TARGET_LOST_TICKS = 60; // 2 seconds until lose target (if shooting)

const NEXT_BULLET_TICKS = 6; // 0.2 seconds for bullet
const LOOP_FIRE_TICKS = 54; // 1.81 seconds for bullet loop

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
 * @property {CBaseEntity} light_ent The light entity of the turret
 * @property {CBaseEntity} fire_ent The fire light entity of the turret
 * @property {CBaseEntity} turret_ent The turret entity
 * @property {number} turretAngle The angle of the turret
 * @property {Vector} currentRotation The current rotation of the turret
 * @property {Vector} targetRotation The target rotation of the turret
 * @property {number} rotationSpeed The speed of the turret rotation
 * @property {boolean} clockwiseRotation Whether the turret is rotating clockwise
 * @property {number} clockwiseSwitchTicks The ticks until the turret switches rotation direction
 * @property {number} detectionTicks The ticks until the turret checks for the player
 * @property {number} chargingTicks The ticks until the turret starts shooting
 * @property {number} targetLostTicks The ticks until the turret loses the target
 * @property {number} nextBulletTicks The ticks until the turret fires the next bullet
 * @property {number} loopFireTicks The ticks until the turret loops fire
 * @property {number} currentState The current state of the turret
 */
class Turret {

    gun_ent = null;
    holder_ent = null;
    mount_ent = null;
    light_ent = null;
    fire_ent = null;
    turret_ent = null;

    // turret rotation
    turretAngle = 0;
    currentRotation = Vector(0, 0);
    targetRotation = Vector(0, 0);
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
    loopFireTicks = 0;
    wasOn = false;

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
            inst.gun_ent.SetAngles(0, -180, 0);

            yield ppmod.create("turret/turret_holder.mdl");
            inst.holder_ent = yielded;
            inst.holder_ent.SetOrigin(origin);
            inst.holder_ent.SetAngles(0, -180, 0);

            yield ppmod.create("turret/turret_mount.mdl");
            inst.mount_ent = yielded;
            inst.mount_ent.SetOrigin(origin);
            inst.mount_ent.SetAngles(0, -180, 0);

            yield ppmod.give("light_dynamic");
            inst.light_ent = yielded[0];
            inst.light_ent.SetOrigin(origin + Vector(-7.6, 1, 55));
            inst.light_ent.SetAngles(0, 0, 0);
            inst.light_ent.Color("255 64 0");
            inst.light_ent.Brightness(5);
            inst.light_ent.Distance(64);

            yield ppmod.give("light_dynamic");
            inst.fire_ent = yielded[0];
            inst.fire_ent.SetOrigin(origin + Vector(26, 0, 47.9));
            inst.fire_ent.SetAngles(0, 0, 0);
            inst.fire_ent.Color("255 0 0");
            inst.fire_ent.Brightness(5);
            inst.fire_ent.Distance(64);

            yield ppmod.create("npc_portal_turret_floor");
            inst.turret_ent = yielded;
            inst.turret_ent.SetOrigin(origin + Vector(12, 0, 11));
            inst.turret_ent.SetAngles(0, 0, 0);
            inst.turret_ent.EnableGagging();
            inst.turret_ent.UsedAsActor = true;
            inst.turret_ent.DiasbleMotion = true;
            inst.turret_ent.MaximumRange = 0;
            inst.turret_ent.MoveType = 0;
            inst.turret_ent.CollisionGroup = 10;
            inst.turret_ent.RenderMode = 10;
            inst.turret_ent.Disable();

            // parent entities
            inst.gun_ent.SetMoveParent(inst.holder_ent);
            inst.holder_ent.SetMoveParent(inst.mount_ent);
            inst.light_ent.SetMoveParent(inst.gun_ent);
            inst.fire_ent.SetMoveParent(inst.gun_ent);
            inst.turret_ent.SetMoveParent(inst.gun_ent);

            inst.light_ent.TurnOff();
            inst.fire_ent.TurnOff();

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
        // calculate angle to player
        local playerOrigin = GetPlayer().GetOrigin() + Vector(0, 0, 36);
        local playerDelta = playerOrigin - this.mount_ent.GetOrigin();
        local playerAngle = (atan2(playerDelta.y, playerDelta.x) * 180/PI) - this.turretAngle - this.currentRotation.x;
        playerAngle = atan2(sin(playerAngle * PI/180), cos(playerAngle * PI/180)) * 180/PI;

        // check angle to player
        if (abs(playerAngle) >= FOCUS_RADIUS || playerAngle + this.currentRotation.x > MAX_ROTATION || playerAngle + this.currentRotation.x < -MAX_ROTATION)
            return false;

        // check distance to player
        if (playerDelta.Length() > FOCUS_DISTANCE)
            return false;

        // check line of sight
        local trace = ppmod.ray(this.gun_ent.GetOrigin(), playerOrigin);
        if (trace.fraction < 1)
            return false;

        // check if player is on same height level
        if (height && abs(playerDelta.z) > FOCUS_HEIGHT)
            return false;

        // aim at player
        if (aim) {
            this.targetRotation.x = max(-MAX_ROTATION, min(MAX_ROTATION, playerAngle + this.currentRotation.x));
            local angle = atan2(playerDelta.Length(), playerDelta.Length2D()) * 180/PI;
            this.targetRotation.y = angle * 2 - 90;
        }

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
                this.loopFireTicks = 0;

                // check for player
                if (this.detectionTicks++ >= DETECTION_TICKS) {
                    this.detectionTicks = RandomInt(0, DETECTION_RAND_TICKS);
                    if (this.checkPlayer()) {
                        this.gun_ent.EmitSound("LethalTurrets.SeePlayer");
                        this.light_ent.TurnOn();
                        this.fire_ent.TurnOff();

                        this.currentState = 2;
                    }
                }

                // rotate the turret
                if (this.clockwiseSwitchTicks++ >= CLOCKWISE_SWITCH_TICKS) {
                    this.clockwiseSwitchTicks = 0;
                    this.clockwiseRotation = !this.clockwiseRotation;
                }

                this.targetRotation.x = max(-MAX_ROTATION, min(MAX_ROTATION, this.targetRotation.x + (this.clockwiseRotation ? rotationSpeed : -rotationSpeed)));
                this.targetRotation.y = 0;
                break;
            case 2: // charging
                // update variables
                this.rotationSpeed = CHARGING_ROTATION_SPEED;
                this.detectionTicks = 0;
                this.clockwiseSwitchTicks = 0;
                this.targetLostTicks = 0;
                this.nextBulletTicks = 0;
                this.loopFireTicks = 0;

                // check for player
                if (this.checkPlayer(true, false)) {
                    // check if focused for long enough
                    if (this.chargingTicks++ >= CHARGING_TICKS) {
                        this.gun_ent.EmitSound("LethalTurrets.Fire");
                        GetPlayer().EmitSound("LethalTurrets.WallHits");
                        this.light_ent.TurnOn();

                        this.currentState = 3;
                    }
                } else {
                    this.light_ent.TurnOff();
                    this.fire_ent.TurnOff();

                    this.currentState = 1;
                }
                break;
            case 3: // firing
                // update variables
                this.rotationSpeed = CHARGING_ROTATION_SPEED;
                this.detectionTicks = 0;
                this.chargingTicks = 0;
                this.clockwiseSwitchTicks = 0;

                // check if lost target for too long
                if (!this.checkPlayer(true, false)) {
                    if (this.targetLostTicks >= TARGET_LOST_TICKS || this.targetLostTicks == -1)
                        this.targetLostTicks = -1;
                    else
                        this.targetLostTicks++;
                } else {
                    this.targetLostTicks = 0;
                }

                // check if light should flicker
                if (this.wasOn)
                    this.fire_ent.TurnOn();
                else
                    this.fire_ent.TurnOff();
                this.wasOn = !this.wasOn;

                // check if should fire bullet
                if (this.nextBulletTicks++ >= NEXT_BULLET_TICKS) {
                    this.nextBulletTicks = 0;

                    if (this.targetLostTicks == 0) {
                        GetPlayer().EmitSound("Flesh.BulletImpact");

                        SendToConsole("hurtme 50");
                    }
                }

                // check if should loop fire
                if (this.loopFireTicks++ >= LOOP_FIRE_TICKS) {
                    this.loopFireTicks = 0;

                    // check if it has to exit now
                    if (this.targetLostTicks == -1) {
                        this.light_ent.TurnOff();
                        this.fire_ent.TurnOff();

                        this.currentState = 1;
                    } else {
                        this.gun_ent.EmitSound("LethalTurrets.Fire");
                        GetPlayer().EmitSound("LethalTurrets.WallHits");
                    }

                }
                break;
            case 4: // TODO: berserk
                break;
        }

        // rotate the turret
        this.currentRotation.x += max(-rotationSpeed, min(rotationSpeed, this.targetRotation.x - this.currentRotation.x));
        this.currentRotation.y += max(-rotationSpeed, min(rotationSpeed, this.targetRotation.y - this.currentRotation.y));
        this.holder_ent.angles = "0 " + (this.currentRotation.x + this.turretAngle - 180) + " 0";
        this.gun_ent.angles = this.currentRotation.y + " " + (this.currentRotation.x + this.turretAngle - 180) + " 0";

        // manage the turret laser
        if (this.currentState >= 2)
            this.turret_ent.angles = (-this.currentRotation.y * 3.5) + " " + (this.currentRotation.x + this.turretAngle) + " 0";
        else
            this.turret_ent.angles = (-this.currentRotation.y * 3.5) + " " + (this.currentRotation.x + this.turretAngle - 180) + " 0";
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
