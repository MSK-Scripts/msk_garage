Translation = Translation or {}

Translation['fr'] = {
    open_garage              = 'Appuyez sur ~g~E~s~ pour ouvrir ~b~%s~s~',
    open_garage_textui       = 'Appuyez sur E pour ouvrir %s',

    no_vehicles              = "Vous n'avez aucun véhicule ici !",
    parked_in                = 'Vous avez garé votre véhicule avec succès.',
    parked_out               = 'Vous avez sorti votre véhicule avec succès.',

    currency                 = '$',

    parkin                   = 'Garer',
    parkout                  = 'Sortir',
    pay_impound              = 'Payer',
    vehicle_park_out         = '~g~Sortir',

    vehicles                 = 'Véhicules',
    favorite_vehicles        = 'Véhicules favoris',

    stat_total               = 'Total',
    stat_favorites           = 'Favoris',
    stat_parked              = 'Garés',
    stat_out                 = 'Sortis',

    rename_popup_title       = 'Renommer le véhicule',
    rename_popup_submit      = 'Confirmer',
    rename_popup_cancel      = 'Annuler',
    rename_input_placeholder = 'Surnom',

    search_input_placeholder = 'Rechercher un véhicule',

    vehicle_impound_track    = 'Localiser',
    vehicle_track            = 'Votre véhicule est déjà sur la route. Un point de repère va être placé.',
    vehicle_track_delete     = 'Votre véhicule va être transporté ici.',

    vehicle_not_owned        = "Ce véhicule ne vous appartient pas.",
    already_parked_out       = 'Déjà sorti',
    already_parked_in        = 'Déjà garé',
    can_be_parked_out        = 'Garé',
    spawnLocations_blocked   = 'Toutes les places de parking sont occupées !',
    no_vehicles_found        = 'Aucun véhicule trouvé à proximité.',

    is_job_vehicle           = "Vous ne pouvez pas garer le véhicule ~y~%s~s~ immatriculé ~y~%s~s~ ici car il appartient à un métier.",
    paid_impound_fee         = 'Vous avez payé $%s.',
    not_enough_money         = "Vous n'avez pas assez d'argent !",

    impound_blocked          = "Ce véhicule est encore dans le monde et doit d'abord être supprimé.",
    impound_blocked_btn      = 'Encore dans le monde',

    job_vehicles             = 'Véhicules de faction',
    key_from                 = 'Clé de %s',
    key_secondary            = 'Double des clés',

    -- Private garages (v5.5.0)
    private_no_access        = 'Tu n\'as pas accès à ce garage.',
    private_no_own_garage    = 'Tu ne possèdes aucun garage privé.',
    private_access_empty     = 'Personne n\'a encore accès à ce garage.',
    private_unknown_garage   = 'Ce garage n\'existe pas.',
    private_not_owner        = 'Seul le propriétaire peut gérer les accès.',
    private_usage            = 'Utilisation : /%s <idGarage> add|remove <idServeur>',
    private_player_not_found = 'Ce joueur n\'est pas connecté.',
    private_self             = 'Tu es le propriétaire, tu as déjà accès.',
    private_limit            = 'La limite de personnes autorisées est atteinte.',
    private_failed           = 'Cela n\'a pas fonctionné.',
    private_not_in_list      = 'Cette personne n\'a pas accès à ce garage.',
    private_granted          = '%s peut désormais utiliser ton garage.',
    private_granted_you      = 'Tu peux désormais utiliser le garage %s.',
    private_revoked          = '%s ne peut plus utiliser ton garage.',
    private_revoked_you      = 'Ton accès au garage %s a été retiré.',
    private_no_permission    = 'Tu n\'as pas la permission de faire cela.',
    private_owner_set        = 'Le garage appartient maintenant à %s.',
    private_owner_cleared    = 'Le garage est de nouveau public.',

    -- Private garage access dialog (v5.5.0)
    access_button            = 'Accès',
    access_title             = 'Gérer les accès',
    access_subtitle          = 'Qui peut se garer ici ?',
    access_placeholder       = 'ID serveur',
    access_add               = 'Ajouter',
    access_remove            = 'Retirer',
    access_close             = 'Fermer',
    access_empty_list        = 'Personne à part toi ne peut encore se garer ici.',
}
