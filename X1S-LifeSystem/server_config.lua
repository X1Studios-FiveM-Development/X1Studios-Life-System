ServerConfig = {
    BotToken = GetConvar('x1s_bot_token', 'BOT_TOKEN_HERE'),
    GuildID = GetConvar('x1s_guild_id', 'GUID_ID_HERE'),
    FooterIcon = 'https://imgur.com/OUmOJay.png', -- DO NOT CHANGE
    LEORoleID = GetConvar('x1s_leo_role_id', 'LEO_ROLE_ID_HERE'),
    AdminRoleID = GetConvar('x1s_admin_role_id', 'ADMIN_ROLE_ID_HERE'),

    Webhooks = {
        LSPD = GetConvar('x1s_lspd_webhook', 'WEBHOOK_LINK_HERE'),
        BCSO = GetConvar('x1s_bcso_webhook', 'WEBHOOK_LINK_HERE'),
        SAST = GetConvar('x1s_sast_webhook', 'WEBHOOK_LINK_HERE'),
        SAGW = GetConvar('x1s_sagw_webhook', 'WEBHOOK_LINK_HERE')
    },
    DispatchWebhook = GetConvar('x1s_dispatch_webhook', 'WEBHOOK_LINK_HERE'),
    PanicWebhook = GetConvar('x1s_panic_webhook', 'WEBHOOK_LINK_HERE'),

    LogWebhooks = {
        characterCreated      = GetConvar('x1s_log_character_created_webhook', 'WEBHOOK_LINK_HERE'),
        characterDeleted      = GetConvar('x1s_log_character_deleted_webhook', 'WEBHOOK_LINK_HERE'),
        playerSpawn           = GetConvar('x1s_log_player_spawn_webhook', 'WEBHOOK_LINK_HERE'),
        citationIssued        = GetConvar('x1s_log_citation_webhook', 'WEBHOOK_LINK_HERE'),
        arrestMade             = GetConvar('x1s_log_arrest_webhook', 'WEBHOOK_LINK_HERE'),
        warrantCreated         = GetConvar('x1s_log_warrant_created_webhook', 'WEBHOOK_LINK_HERE'),
        warrantClosed          = GetConvar('x1s_log_warrant_closed_webhook', 'WEBHOOK_LINK_HERE'),
        vehicleBoloCreated     = GetConvar('x1s_log_vehicle_bolo_created_webhook', 'WEBHOOK_LINK_HERE'),
        vehicleBoloClosed      = GetConvar('x1s_log_vehicle_bolo_closed_webhook', 'WEBHOOK_LINK_HERE'),
        vehicleRegistered      = GetConvar('x1s_log_vehicle_registered_webhook', 'WEBHOOK_LINK_HERE'),
        vehicleStolenToggled   = GetConvar('x1s_log_vehicle_stolen_webhook', 'WEBHOOK_LINK_HERE'),
        vehicleRegistrationRenewed   = GetConvar('x1s_log_vehicle_renewed_webhook', 'WEBHOOK_LINK_HERE'),
        vehicleOwnershipTransferred  = GetConvar('x1s_log_vehicle_transferred_webhook', 'WEBHOOK_LINK_HERE'),
        vehicleRetiredToggled        = GetConvar('x1s_log_vehicle_retired_webhook', 'WEBHOOK_LINK_HERE'),
        citizenNotesUpdated    = GetConvar('x1s_log_citizen_notes_webhook', 'WEBHOOK_LINK_HERE'),
        citizenLicenseUpdated  = GetConvar('x1s_log_citizen_license_webhook', 'WEBHOOK_LINK_HERE'),
        citizenFlagsUpdated    = GetConvar('x1s_log_citizen_flags_webhook', 'WEBHOOK_LINK_HERE'),
        incidentCreated        = GetConvar('x1s_log_incident_webhook', 'WEBHOOK_LINK_HERE'),
        cadReferenceDataChanged = GetConvar('x1s_log_cad_admin_webhook', 'WEBHOOK_LINK_HERE'),
        cadRecordDeleted = GetConvar('x1s_log_cad_record_deleted_webhook', 'WEBHOOK_LINK_HERE')
    },

    Departments = {
        LSPD = {
            dutyRole = GetConvar('x1s_lspd_duty_role', 'ROLE_ID_HERE'),
            supervisorRole = GetConvar('x1s_lspd_supervisor_role', 'ROLE_ID_HERE'),
            webhookThumbnail = 'https://i.imgur.com/PCRR7pN.png'
        },
        BCSO = {
            dutyRole = GetConvar('x1s_bcso_duty_role', 'ROLE_ID_HERE'),
            supervisorRole = GetConvar('x1s_bcso_supervisor_role', 'ROLE_ID_HERE'),
            webhookThumbnail = 'https://i.imgur.com/MWL8fOL.png'
        },
        SAST = {
            dutyRole = GetConvar('x1s_sast_duty_role', 'ROLE_ID_HERE'),
            supervisorRole = GetConvar('x1s_sast_supervisor_role', 'ROLE_ID_HERE'),
            webhookThumbnail = 'https://i.imgur.com/qwjPGhj.png'
        },
        SAGW = {
            dutyRole = GetConvar('x1s_sagw_duty_role', 'ROLE_ID_HERE'),
            supervisorRole = GetConvar('x1s_sagw_supervisor_role', 'ROLE_ID_HERE'),
            webhookThumbnail = 'https://imgur.com/DbT5klb.png'
        }
    },

    Cooldowns = {
        emergencyCall = 30,
        panic = 15,
        dutyRequest = 5,
        supervisorRequest = 3,
        forceOff = 2,
        calls911Request = 2,
        dismiss911 = 2,
        clearPanic = 3,
        cadSearch = 1,
        cadWrite = 1,
        cadFlagWrite = 1,
        vehicleRegister = 5,
        vehicleList = 2,
        handCard = 3
    }
}
