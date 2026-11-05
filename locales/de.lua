Translation = Translation or {}

Translation['de'] = {
    open_garage              = 'Drücke ~g~E~s~ um ~b~%s~s~ zu betreten',
    open_garage_textui       = 'Drücke E um %s zu betreten',

    no_vehicles              = 'Du hast hier keine Fahrzeuge',
    parked_in                = 'Du hast dein Fahrzeug erfolgreich eingeparkt.',
    parked_out               = 'Du hast dein Fahrzeug erfolgreich ausgeparkt.',

    currency                 = '$',

    parkin                   = 'Einparken',
    parkout                  = 'Ausparken',
    pay_impound              = 'Freikaufen',
    vehicle_park_out         = '~g~Ausparken',

    vehicles                 = 'Fahrzeuge',
    favorite_vehicles        = 'Favorisierte Fahrzeuge',

    stat_total               = 'Gesamt',
    stat_favorites           = 'Favoriten',
    stat_parked              = 'Eingeparkt',
    stat_out                 = 'Unterwegs',

    rename_popup_title       = 'Fahrzeug umbenennen',
    rename_popup_submit      = 'Bestätigen',
    rename_popup_cancel      = 'Abbrechen',
    rename_input_placeholder = 'Nickname',

    search_input_placeholder = 'Fahrzeug suchen',

    vehicle_impound_track    = 'Orten',
    vehicle_track            = 'Dein Fahrzeug befindet sich bereits auf den Straßen. Es wird ein Wegpunkt gesetzt.',
    vehicle_track_delete     = 'Dein Fahrzeug wird hierher transportiert.',

    vehicle_not_owned        = 'Dieses Fahrzeug gehört dir nicht.',
    already_parked_out       = 'Bereits ausgeparkt',
    already_parked_in        = 'Bereits eingeparkt',
    can_be_parked_out        = 'Eingeparkt',
    spawnLocations_blocked   = 'Es sind keine Parkflächen mehr frei!',
    no_vehicles_found        = 'Es sind keine Fahrzeuge in deiner Nähe',

    is_job_vehicle           = 'Du kannst das Fahrzeug ~y~%s~s~ mit dem Kennzeichen ~y~%s~s~ hier nicht einparken, da es einem Job gehört.',
    paid_impound_fee         = 'Du hast $%s gezahlt.',
    not_enough_money         = 'Du hast nicht genug Geld!',

    impound_blocked          = 'Dieses Fahrzeug steht noch in der Welt und muss erst entfernt werden.',
    impound_blocked_btn      = 'Noch in der Welt',

    job_vehicles             = 'Fraktionsfahrzeuge',
    key_from                 = 'Schlüssel von %s',
    key_secondary            = 'Zweitschlüssel',

    -- Private garages (v5.5.0)
    private_no_access        = 'Du hast keinen Zugriff auf diese Garage.',
    private_no_own_garage    = 'Du besitzt keine Privatgarage.',
    private_access_empty     = 'Bisher hat niemand Zugriff auf diese Garage.',
    private_unknown_garage   = 'Diese Garage gibt es nicht.',
    private_not_owner        = 'Nur der Eigentümer kann den Zugriff verwalten.',
    private_usage            = 'Nutzung: /%s <GaragenId> add|remove <ServerId>',
    private_player_not_found = 'Dieser Spieler ist nicht online.',
    private_self             = 'Du hast als Eigentümer ohnehin Zugriff.',
    private_limit            = 'Das Limit an berechtigten Personen ist erreicht.',
    private_failed           = 'Das hat nicht geklappt.',
    private_not_in_list      = 'Diese Person hat keinen Zugriff auf die Garage.',
    private_granted          = '%s darf deine Garage jetzt nutzen.',
    private_granted_you      = 'Du darfst jetzt die Garage %s nutzen.',
    private_revoked          = '%s darf deine Garage nicht mehr nutzen.',
    private_revoked_you      = 'Dein Zugriff auf die Garage %s wurde entzogen.',
    private_no_permission    = 'Dir fehlt die Berechtigung dafür.',
    private_owner_set        = 'Die Garage gehört jetzt %s.',
    private_owner_cleared    = 'Die Garage ist wieder öffentlich.',

    -- Private garage access dialog (v5.5.0)
    access_button            = 'Zugriff',
    access_title             = 'Zugriff verwalten',
    access_subtitle          = 'Wer darf hier parken?',
    access_placeholder       = 'Server-ID',
    access_add               = 'Hinzufügen',
    access_remove            = 'Entfernen',
    access_close             = 'Schließen',
    access_empty_list        = 'Bisher darf niemand außer dir hier parken.',
}
