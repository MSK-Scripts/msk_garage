Translation = Translation or {}

Translation['es'] = {
    open_garage              = 'Pulsa ~g~E~s~ para abrir ~b~%s~s~',
    open_garage_textui       = 'Pulsa E para abrir %s',

    no_vehicles              = '¡No tienes vehículos aquí!',
    parked_in                = 'Has guardado tu vehículo correctamente.',
    parked_out               = 'Has sacado tu vehículo correctamente.',

    currency                 = '$',

    parkin                   = 'Guardar',
    parkout                  = 'Sacar',
    pay_impound              = 'Pagar',
    vehicle_park_out         = '~g~Sacar',

    vehicles                 = 'Vehículos',
    favorite_vehicles        = 'Vehículos favoritos',

    stat_total               = 'Total',
    stat_favorites           = 'Favoritos',
    stat_parked              = 'Guardados',
    stat_out                 = 'Fuera',

    rename_popup_title       = 'Renombrar vehículo',
    rename_popup_submit      = 'Confirmar',
    rename_popup_cancel      = 'Cancelar',
    rename_input_placeholder = 'Apodo',

    search_input_placeholder = 'Buscar vehículo',

    vehicle_impound_track    = 'Localizar',
    vehicle_track            = 'Tu vehículo ya está en la carretera. Se establecerá un punto de ruta.',
    vehicle_track_delete     = 'Tu vehículo será transportado aquí.',

    vehicle_not_owned        = 'Este vehículo no es tuyo.',
    already_parked_out       = 'Ya está fuera',
    already_parked_in        = 'Ya está guardado',
    can_be_parked_out        = 'Guardado',
    spawnLocations_blocked   = '¡Todas las plazas de aparcamiento están ocupadas!',
    no_vehicles_found        = 'No se encontraron vehículos cerca.',

    is_job_vehicle           = 'No puedes guardar el vehículo ~y~%s~s~ con matrícula ~y~%s~s~ aquí porque pertenece a un trabajo.',
    paid_impound_fee         = 'Has pagado $%s.',
    not_enough_money         = '¡No tienes suficiente dinero!',

    impound_blocked          = 'Este vehículo sigue en el mundo y primero debe ser eliminado.',
    impound_blocked_btn      = 'Sigue en el mundo',

    job_vehicles             = 'Vehículos de facción',
    key_from                 = 'Llave de %s',
    key_secondary            = 'Segunda llave',

    -- Private garages (v5.5.0)
    private_no_access        = 'No tienes acceso a este garaje.',
    private_no_own_garage    = 'No posees ningún garaje privado.',
    private_access_empty     = 'Todavía nadie tiene acceso a este garaje.',
    private_unknown_garage   = 'Ese garaje no existe.',
    private_not_owner        = 'Solo el propietario puede gestionar el acceso.',
    private_usage            = 'Uso: /%s <idGaraje> add|remove <idServidor>',
    private_player_not_found = 'Ese jugador no está conectado.',
    private_self             = 'Eres el propietario, ya tienes acceso.',
    private_limit            = 'Se ha alcanzado el límite de personas permitidas.',
    private_failed           = 'Eso no ha funcionado.',
    private_not_in_list      = 'Esa persona no tiene acceso a este garaje.',
    private_granted          = '%s ya puede usar tu garaje.',
    private_granted_you      = 'Ahora puedes usar el garaje %s.',
    private_revoked          = '%s ya no puede usar tu garaje.',
    private_revoked_you      = 'Se te ha retirado el acceso al garaje %s.',
    private_no_permission    = 'No tienes permiso para hacer eso.',
    private_owner_set        = 'El garaje pertenece ahora a %s.',
    private_owner_cleared    = 'El garaje vuelve a ser público.',

    -- Private garage access dialog (v5.5.0)
    access_button            = 'Acceso',
    access_title             = 'Gestionar acceso',
    access_subtitle          = '¿Quién puede aparcar aquí?',
    access_placeholder       = 'ID de servidor',
    access_add               = 'Añadir',
    access_remove            = 'Quitar',
    access_close             = 'Cerrar',
    access_empty_list        = 'Todavía nadie más que tú puede aparcar aquí.',
}
