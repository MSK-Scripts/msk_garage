Translation = Translation or {}

Translation['hu'] = {
    open_garage              = 'Nyomd meg az ~g~E~s~ gombot a ~b~%s~s~ megnyitásához',
    open_garage_textui       = 'Nyomd meg az E gombot a(z) %s megnyitásához',

    no_vehicles              = 'Nincs itt járműved!',
    parked_in                = 'Sikeresen leparkoltad a járművedet.',
    parked_out               = 'Sikeresen kiállítottad a járművedet.',

    currency                 = '$',

    parkin                   = 'Beállás',
    parkout                  = 'Kiállás',
    pay_impound              = 'Fizetés',
    vehicle_park_out         = '~g~Kiállás',

    vehicles                 = 'Járművek',
    favorite_vehicles        = 'Kedvenc járművek',

    stat_total               = 'Összes',
    stat_favorites           = 'Kedvencek',
    stat_parked              = 'Leparkolva',
    stat_out                 = 'Kint',

    rename_popup_title       = 'Jármű átnevezése',
    rename_popup_submit      = 'Megerősítés',
    rename_popup_cancel      = 'Mégse',
    rename_input_placeholder = 'Becenév',

    search_input_placeholder = 'Jármű keresése',

    vehicle_impound_track    = 'Követés',
    vehicle_track            = 'A járműved már az utcán van. Egy útpont lesz beállítva.',
    vehicle_track_delete     = 'A járműved ide lesz szállítva.',

    vehicle_not_owned        = 'Ez a jármű nem a tiéd.',
    already_parked_out       = 'Már kiállítva',
    already_parked_in        = 'Már leparkolva',
    can_be_parked_out        = 'Leparkolva',
    spawnLocations_blocked   = 'Minden parkolóhely foglalt!',
    no_vehicles_found        = 'Nincs jármű a közeledben.',

    is_job_vehicle           = 'A(z) ~y~%s~s~ járművet a(z) ~y~%s~s~ rendszámmal nem tudod itt leparkolni, mert egy munkához tartozik.',
    paid_impound_fee         = 'Fizettél $%s összeget.',
    not_enough_money         = 'Nincs elég pénzed!',

    impound_blocked          = 'Ez a jármű még kint van a világban, előbb el kell távolítani.',
    impound_blocked_btn      = 'Még a világban',

    job_vehicles             = 'Frakció járművek',
    key_from                 = '%s kulcsa',
    key_secondary            = 'Pótkulcs',

    -- Private garages (v5.5.0)
    private_no_access        = 'Nincs hozzáférésed ehhez a garázshoz.',
    private_no_own_garage    = 'Nincs saját magángarázsod.',
    private_access_empty     = 'Még senkinek nincs hozzáférése ehhez a garázshoz.',
    private_unknown_garage   = 'Ez a garázs nem létezik.',
    private_not_owner        = 'Csak a tulajdonos kezelheti a hozzáféréseket.',
    private_usage            = 'Használat: /%s <garázsId> add|remove <szerverId>',
    private_player_not_found = 'Ez a játékos nincs fent.',
    private_self             = 'Te vagy a tulajdonos, már van hozzáférésed.',
    private_limit            = 'Elérted az engedélyezett személyek felső határát.',
    private_failed           = 'Ez nem sikerült.',
    private_not_in_list      = 'Ennek a személynek nincs hozzáférése a garázshoz.',
    private_granted          = '%s mostantól használhatja a garázsodat.',
    private_granted_you      = 'Mostantól használhatod a(z) %s garázst.',
    private_revoked          = '%s többé nem használhatja a garázsodat.',
    private_revoked_you      = 'A(z) %s garázshoz való hozzáférésedet visszavonták.',
    private_no_permission    = 'Nincs jogosultságod ehhez.',
    private_owner_set        = 'A garázs mostantól %s tulajdona.',
    private_owner_cleared    = 'A garázs újra nyilvános.',

    -- Private garage access dialog (v5.5.0)
    access_button            = 'Hozzáférés',
    access_title             = 'Hozzáférés kezelése',
    access_subtitle          = 'Ki parkolhat itt?',
    access_placeholder       = 'Szerver ID',
    access_add               = 'Hozzáadás',
    access_remove            = 'Eltávolítás',
    access_close             = 'Bezárás',
    access_empty_list        = 'Rajtad kívül még senki nem parkolhat itt.',
}
