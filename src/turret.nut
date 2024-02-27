/** Offset between the turret base and gun. This is required in order to rotate the turret around the point where it's held */
const GUN_OFFSET = 47.6;
/** Pan speed */
const PAN_SPEED = 0.0125;

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
 *
 */
class Turret {

    gun_ent = null;
    holder_ent = null;
    mount_ent = null;

    pan = 0;
    angle = 0;

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
     * Tick the turret
     */
    function tick() {
        this.pan += PAN_SPEED;
        if (this.target)
            return;

        // pan the turret
        local localPanAngle = sin(this.pan) * 90;
        local globalPanAngle = localPanAngle + this.angle;
        this.holder_ent.angles = "0 " + (globalPanAngle - 180) + " 0";

        // get angle to player
        local deltaPlayerPos = GetPlayer().GetOrigin() - this.mount_ent.GetOrigin();
        local deltaPlayerAngle = atan2(deltaPlayerPos.y, deltaPlayerPos.x) * 180/PI;
        local localDeltaPlayerAngle = deltaPlayerAngle - this.angle;
        localDeltaPlayerAngle = atan2(sin(localDeltaPlayerAngle * PI/180), cos(localDeltaPlayerAngle * PI/180)) * 180/PI;
        local panDelta = localDeltaPlayerAngle - localPanAngle;
        printl(panDelta);
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
