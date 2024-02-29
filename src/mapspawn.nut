if (!("Entities" in this)) return;
IncludeScript("ppmod4");
IncludeScript("turret");

::turret <- null;

ppmod.onauto(function() {
    // precache turret
    ppmod.create("npc_portal_turret_floor").then(function (dummy) {
        dummy.Destroy();
    });

    newTurret(Vector(7983, -5849, 0)).then(function (turret) {
        ::turret = turret;
        turret.rotate(110);
    });
});

ppmod.interval(function() {
    if (!::turret)
        return;

    ::turret.tick();
}, 0.0, "lethalturrets-tick");
