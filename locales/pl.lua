Translation = Translation or {}

Translation['pl'] = {
    open_garage              = 'Naciśnij ~g~E~s~, aby otworzyć ~b~%s~s~',
    open_garage_textui       = 'Naciśnij E, aby otworzyć %s',

    no_vehicles              = 'Nie masz tu żadnych pojazdów!',
    parked_in                = 'Pomyślnie zaparkowałeś swój pojazd.',
    parked_out               = 'Pomyślnie wyprowadziłeś swój pojazd.',

    currency                 = '$',

    parkin                   = 'Zaparkuj',
    parkout                  = 'Wyprowadź',
    pay_impound              = 'Zapłać',
    vehicle_park_out         = '~g~Wyprowadź',

    vehicles                 = 'Pojazdy',
    favorite_vehicles        = 'Ulubione pojazdy',

    stat_total               = 'Łącznie',
    stat_favorites           = 'Ulubione',
    stat_parked              = 'Zaparkowane',
    stat_out                 = 'Na zewnątrz',

    rename_popup_title       = 'Zmień nazwę pojazdu',
    rename_popup_submit      = 'Potwierdź',
    rename_popup_cancel      = 'Anuluj',
    rename_input_placeholder = 'Pseudonim',

    search_input_placeholder = 'Szukaj pojazdu',

    vehicle_impound_track    = 'Śledź',
    vehicle_track            = 'Twój pojazd jest już na drodze. Zostanie ustawiony punkt nawigacji.',
    vehicle_track_delete     = 'Twój pojazd zostanie tu przetransportowany.',

    vehicle_not_owned        = 'Ten pojazd nie należy do ciebie.',
    already_parked_out       = 'Już wyprowadzony',
    already_parked_in        = 'Już zaparkowany',
    can_be_parked_out        = 'Zaparkowany',
    spawnLocations_blocked   = 'Wszystkie miejsca parkingowe są zajęte!',
    no_vehicles_found        = 'Nie znaleziono pojazdów w pobliżu.',

    is_job_vehicle           = 'Nie możesz tu zaparkować pojazdu ~y~%s~s~ o numerze rejestracyjnym ~y~%s~s~, ponieważ należy on do pracy.',
    paid_impound_fee         = 'Zapłaciłeś $%s.',
    not_enough_money         = 'Nie masz wystarczająco pieniędzy!',

    impound_blocked          = 'Ten pojazd wciąż znajduje się w świecie i musi najpierw zostać usunięty.',
    impound_blocked_btn      = 'Wciąż w świecie',

    job_vehicles             = 'Pojazdy frakcyjne',
    key_from                 = 'Klucz od %s',
    key_secondary            = 'Zapasowy klucz',

    -- Private garages (v5.5.0)
    private_no_access        = 'Nie masz dostępu do tego garażu.',
    private_no_own_garage    = 'Nie posiadasz prywatnego garażu.',
    private_access_empty     = 'Nikt nie ma jeszcze dostępu do tego garażu.',
    private_unknown_garage   = 'Taki garaż nie istnieje.',
    private_not_owner        = 'Tylko właściciel może zarządzać dostępem.',
    private_usage            = 'Użycie: /%s <idGarażu> add|remove <idSerwera>',
    private_player_not_found = 'Tego gracza nie ma na serwerze.',
    private_self             = 'Jesteś właścicielem, masz już dostęp.',
    private_limit            = 'Osiągnięto limit uprawnionych osób.',
    private_failed           = 'To się nie udało.',
    private_not_in_list      = 'Ta osoba nie ma dostępu do tego garażu.',
    private_granted          = '%s może teraz korzystać z twojego garażu.',
    private_granted_you      = 'Możesz teraz korzystać z garażu %s.',
    private_revoked          = '%s nie może już korzystać z twojego garażu.',
    private_revoked_you      = 'Twój dostęp do garażu %s został cofnięty.',
    private_no_permission    = 'Nie masz do tego uprawnień.',
    private_owner_set        = 'Garaż należy teraz do %s.',
    private_owner_cleared    = 'Garaż jest znowu publiczny.',

    -- Private garage access dialog (v5.5.0)
    access_button            = 'Dostęp',
    access_title             = 'Zarządzaj dostępem',
    access_subtitle          = 'Kto może tu parkować?',
    access_placeholder       = 'ID serwera',
    access_add               = 'Dodaj',
    access_remove            = 'Usuń',
    access_close             = 'Zamknij',
    access_empty_list        = 'Poza tobą nikt nie może jeszcze tu parkować.',
}
