if (!("Entities" in this)) return;
IncludeScript("ppmod4");
IncludeScript("turret");

::turret <- null;

ppmod.onauto(function() {
    newTurret(Vector(7983, -5849, 0)).then(function (turret) {
        ::turret = turret;
    });
});

ppmod.interval(function() {
    if (!::turret)
        return;

    ::turret.tick();
}, 0.0, "lethalturrets-tick");
