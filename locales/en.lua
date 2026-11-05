Translation = Translation or {}

Translation['en'] = {
    open_garage              = 'Press ~g~E~s~ to open ~b~%s~s~',
    open_garage_textui       = 'Press E to open %s',

    no_vehicles              = "You don't have vehicles here!",
    parked_in                = 'You successfully parked in your vehicle.',
    parked_out               = 'You successfully parked out your vehicle.',

    currency                 = '$',

    parkin                   = 'Park In',
    parkout                  = 'Park Out',
    pay_impound              = 'Pay',
    vehicle_park_out         = '~g~Park out',

    vehicles                 = 'Vehicles',
    favorite_vehicles        = 'Favorite Vehicles',

    stat_total               = 'Total',
    stat_favorites           = 'Favorites',
    stat_parked              = 'Parked',
    stat_out                 = 'Out',

    rename_popup_title       = 'Rename Vehicle',
    rename_popup_submit      = 'Submit',
    rename_popup_cancel      = 'Cancel',
    rename_input_placeholder = 'Nickname',

    search_input_placeholder = 'Search Vehicle',

    vehicle_impound_track    = 'Track',
    vehicle_track            = 'Your vehicle is already on the road. A waypoint will be set.',
    vehicle_track_delete     = 'Your vehicle will be transported here.',

    vehicle_not_owned        = 'This vehicle is not yours.',
    already_parked_out       = 'Already parked out',
    already_parked_in        = 'Already parked in',
    can_be_parked_out        = 'Parked In',
    spawnLocations_blocked   = 'All parking spots are blocked!',
    no_vehicles_found        = 'No vehicles found in your area.',

    is_job_vehicle           = "You can't park the vehicle ~y~%s~s~ with plate ~y~%s~s~ here because it belongs to a job.",
    paid_impound_fee         = 'You paid $%s.',
    not_enough_money         = "You don't have enough money!",

    impound_blocked          = 'This vehicle is still out in the world and has to be removed first.',
    impound_blocked_btn      = 'Still in the world',

    job_vehicles             = 'Faction vehicles',
    key_from                 = 'Key from %s',
    key_secondary            = 'Second key',

    -- Private garages (v5.5.0)
    private_no_access        = 'You do not have access to this garage.',
    private_no_own_garage    = 'You do not own a private garage.',
    private_access_empty     = 'Nobody has access to this garage yet.',
    private_unknown_garage   = 'That garage does not exist.',
    private_not_owner        = 'Only the owner can manage access.',
    private_usage            = 'Usage: /%s <garageId> add|remove <serverId>',
    private_player_not_found = 'That player is not online.',
    private_self             = 'You are the owner, you already have access.',
    private_limit            = 'The limit of allowed people has been reached.',
    private_failed           = 'That did not work.',
    private_not_in_list      = 'That person has no access to this garage.',
    private_granted          = '%s may now use your garage.',
    private_granted_you      = 'You may now use the garage %s.',
    private_revoked          = '%s may no longer use your garage.',
    private_revoked_you      = 'Your access to the garage %s was removed.',
    private_no_permission    = 'You are not allowed to do that.',
    private_owner_set        = 'The garage now belongs to %s.',
    private_owner_cleared    = 'The garage is public again.',

    -- Private garage access dialog (v5.5.0)
    access_button            = 'Access',
    access_title             = 'Manage access',
    access_subtitle          = 'Who may park here?',
    access_placeholder       = 'Server ID',
    access_add               = 'Add',
    access_remove            = 'Remove',
    access_close             = 'Close',
    access_empty_list        = 'Nobody but you may park here yet.',
}
