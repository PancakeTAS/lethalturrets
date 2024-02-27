/** Offset between the turret base and gun. This is required in order to rotate the turret around the point where it's held */
const GUN_OFFSET = 47.6;
/** Pan speed */
const PAN_SPEED = 0.0125;
const DETECTION_TICKS = 8; // 0.25 interval to check for player
const LOSE_TARGET_TICKS = 60; // 2 seconds until lose target (if shooting)
const FOCUS_TICKS = 45; // 1.5 seconds until shoot
const BULLET_TICKS = 6; // 0.2 seconds for bullet

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
 * @property {number} pan The progress of the pan
 * @property {number} angle The angle of the turret
 * @property {CBaseEntity} target The target of the turret
 * @property {number} currentState The current state of the turret
 * @property {number} checkPlayerTicks The amount of ticks the turret has checked for the player
 * @property {number} targetLoseTicks The amount of ticks the turret has lost the target
 * @property {number} nextBulletTicks The amount of ticks until the next bullet is fired
 * @property {number} focusTicks The amount of ticks the turret has been focused on the target
 */
class Turret {

    gun_ent = null;
    holder_ent = null;
    mount_ent = null;

    pan = 0;
    angle = 0;

    currentState = 1; // 0 = deactivated, 1 = detection, 2 = charging, 3 = firing, 4 = berserk
    checkPlayerTicks = 0;
    focusTicks = 0;
    targetLoseTicks = 0;
    nextBulletTicks = 0;

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

            // parent entities
            inst.gun_ent.SetMoveParent(inst.holder_ent);
            inst.holder_ent.SetMoveParent(inst.mount_ent);

            resolve(inst);

        }));
    }

    /**
     * Check if the player is in range of the turret
     *
     * @param {boolean} aim Whether to aim at the player
     * @param {boolean} enlarge Whether to enlarge the radius of the check
     */
    function checkPlayer(aim, enlarge = false) {
        // TODO: constants

        // calculate angle to player
        local lPlayer = GetPlayer().GetOrigin() - this.mount_ent.GetOrigin();
        local lPlayerAng = atan2(lPlayer.y, lPlayer.x) * 180/PI;
        local lDeltaAng = lPlayerAng - this.angle;

        // aim at player
        if (aim) {
            lDeltaAng = atan2(sin(lDeltaAng * PI/180), cos(lDeltaAng * PI/180)) * 180/PI;
            local newlDeltaAng = lDeltaAng;
            if (enlarge)
                newlDeltaAng = min(110, max(-110, lDeltaAng));
            else
                newlDeltaAng = min(90, max(-90, lDeltaAng));

            if (newlDeltaAng != lDeltaAng)
                aim = false;

            this.holder_ent.angles = "0 " + (newlDeltaAng - 180) + " 0";
        }

        // check angle to player < 15
        lDeltaAng = atan2(sin(lDeltaAng * PI/180), cos(lDeltaAng * PI/180)) * 180/PI;
        local panDelta = lDeltaAng - (sin(this.pan) * 90);
        if (abs(panDelta) >= 15 && !aim)
            return false;

        // check distance to player < 500
        if (lPlayer.Length() > 500)
            return false;

        // check line of sight
        local trace = ppmod.ray(this.gun_ent.GetOrigin(), GetPlayer().GetOrigin());
        if (trace.fraction < 1)
            return false;

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
                // check for player
                if (this.checkPlayerTicks++ >= DETECTION_TICKS) {
                    this.checkPlayerTicks = 0;
                    if (this.checkPlayer(false)) {
                        this.currentState = 2;
                        printl("Switching to charging");
                    }
                }

                // pan the turret
                this.pan += PAN_SPEED;
                this.holder_ent.angles = "0 " + (sin(this.pan) * 90 + this.angle - 180) + " 0";
                break;
            case 2: // charging
                // check for player
                if (this.checkPlayer(true)) {
                    // check if focused for long enough
                    if (focusTicks++ >= FOCUS_TICKS) {
                        this.focusTicks = 0;
                        this.currentState = 3;
                        printl("Switching to firing");
                    }
                } else {
                    this.focusTicks = 0;
                    this.currentState = 1;
                    printl("Switching to detection");
                }
                break;
            case 3: // firing
                if (!this.checkPlayer(true, true)) {
                    // check if lost target for too long
                    if (this.targetLoseTicks++ >= LOSE_TARGET_TICKS) {
                        this.targetLoseTicks = 0;
                        this.currentState = 1;
                        printl("Switching to detection");
                    }
                }

                // check if should fire bullet
                if (this.nextBulletTicks++ >= BULLET_TICKS) {
                    this.nextBulletTicks = 0;
                    print("F");
                }
                break;
            case 4: // TODO: berserk
                break;
        }
    }

    /**
     * Set the base angle of the turret
     *
     * @param {number} angle The new angle in degrees of the turret
     */
    function rotate(angle) {
        this.angle = angle;
        this.mount_ent.angles = "0 " + (angle - 180) + " 0";
    }

}
