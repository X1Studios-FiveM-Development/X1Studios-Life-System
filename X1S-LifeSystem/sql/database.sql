-- X1S Life System - database schema

CREATE TABLE IF NOT EXISTS `x1s_characters` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `state_id`      VARCHAR(16)  NOT NULL,
    `identifier`    VARCHAR(64)  NOT NULL,
    `first_name`    VARCHAR(32)  NOT NULL,
    `last_name`     VARCHAR(32)  NOT NULL,
    `dob`           DATE         NOT NULL,
    `gender`        VARCHAR(16)  NOT NULL,
    `height`        SMALLINT UNSIGNED NOT NULL,
    `licenses`      LONGTEXT     NULL,
    `address`       VARCHAR(96)  NULL,
    `notes`         TEXT         NULL,
    `is_dead`       TINYINT(1)   NOT NULL DEFAULT 0,
    `is_armed`      TINYINT(1)   NOT NULL DEFAULT 0,
    `is_violent`    TINYINT(1)   NOT NULL DEFAULT 0,
    `is_mentally_ill` TINYINT(1) NOT NULL DEFAULT 0,
    `last_played`   DATETIME     NULL,
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `deleted_at`    DATETIME     NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_state_id` (`state_id`),
    KEY `idx_identifier` (`identifier`),
    KEY `idx_name` (`last_name`, `first_name`),
    KEY `idx_dob` (`dob`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `x1s_vehicles` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `plate`         VARCHAR(16)  NOT NULL,
    `owner_id`      INT UNSIGNED NULL,
    `brand`         VARCHAR(32)  NULL,
    `vehicle_type`  VARCHAR(32)  NULL,
    `model`         VARCHAR(64)  NOT NULL,
    `color`         VARCHAR(32)  NULL,
    `registration`  ENUM('valid','expired','unregistered') NOT NULL DEFAULT 'valid',
    `insured`       TINYINT(1)   NOT NULL DEFAULT 1,
    `stolen`        TINYINT(1)   NOT NULL DEFAULT 0,
    `notes`         TEXT         NULL,
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_plate` (`plate`),
    KEY `idx_owner` (`owner_id`),
    CONSTRAINT `fk_vehicle_owner` FOREIGN KEY (`owner_id`) REFERENCES `x1s_characters` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `x1s_warrants` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id`  INT UNSIGNED NOT NULL,
    `department`    VARCHAR(16)  NOT NULL,
    `reason`        VARCHAR(255) NOT NULL,
    `charges`       LONGTEXT     NULL,
    `notes`         TEXT         NULL,
    `status`        ENUM('active','closed') NOT NULL DEFAULT 'active',
    `issued_by`     VARCHAR(64)  NOT NULL,
    `issued_by_id`  INT UNSIGNED NULL,
    `signature`     VARCHAR(64)  NULL,
    `is_armed`      TINYINT(1)   NOT NULL DEFAULT 0,
    `is_violent`    TINYINT(1)   NOT NULL DEFAULT 0,
    `is_mentally_ill` TINYINT(1) NOT NULL DEFAULT 0,
    `expires_at`    DATETIME     NULL,
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at`     DATETIME     NULL,
    PRIMARY KEY (`id`),
    KEY `idx_character` (`character_id`),
    KEY `idx_status` (`status`),
    CONSTRAINT `fk_warrant_character` FOREIGN KEY (`character_id`) REFERENCES `x1s_characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `x1s_arrests` (
    `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id`   INT UNSIGNED NOT NULL,
    `officer_name`   VARCHAR(64)  NOT NULL,
    `officer_id`     INT UNSIGNED NULL,
    `department`     VARCHAR(16)  NOT NULL,
    `charges`        LONGTEXT     NOT NULL,
    `fine_total`     INT UNSIGNED NOT NULL DEFAULT 0,
    `jail_minutes`   INT UNSIGNED NOT NULL DEFAULT 0,
    `notes`          TEXT         NULL,
    `assisting`      LONGTEXT     NULL,
    `signature`      VARCHAR(64)  NULL,
    `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_character` (`character_id`),
    CONSTRAINT `fk_arrest_character` FOREIGN KEY (`character_id`) REFERENCES `x1s_characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `x1s_citations` (
    `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `character_id`   INT UNSIGNED NOT NULL,
    `officer_name`   VARCHAR(64)  NOT NULL,
    `officer_id`     INT UNSIGNED NULL,
    `department`     VARCHAR(16)  NOT NULL,
    `violation`      VARCHAR(128) NULL,
    `fine`           INT UNSIGNED NULL DEFAULT 0,
    `violations`     LONGTEXT     NULL,
    `fine_total`     INT UNSIGNED NOT NULL DEFAULT 0,
    `signature`      VARCHAR(64)  NULL,
    `notes`          TEXT         NULL,
    `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_character` (`character_id`),
    CONSTRAINT `fk_citation_character` FOREIGN KEY (`character_id`) REFERENCES `x1s_characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `x1s_incidents` (
    `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `case_number`    VARCHAR(24)  NOT NULL,
    `title`          VARCHAR(128) NOT NULL,
    `department`     VARCHAR(16)  NOT NULL,
    `officers`       LONGTEXT     NULL,
    `civilians`      LONGTEXT     NULL,
    `narrative`      LONGTEXT     NULL,
    `evidence`       LONGTEXT     NULL,
    `signing_officer` VARCHAR(64) NULL,
    `status`         ENUM('open','closed') NOT NULL DEFAULT 'open',
    `created_by`     VARCHAR(64)  NULL,
    `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_case_number` (`case_number`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `x1s_vehicle_bolos` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `plate`         VARCHAR(16)  NULL,
    `brand`         VARCHAR(32)  NULL,
    `vehicle_type`  VARCHAR(64)  NULL,
    `model`         VARCHAR(64)  NULL,
    `color`         VARCHAR(32)  NULL,
    `reason`        VARCHAR(255) NOT NULL,
    `priority`      VARCHAR(16)  NOT NULL DEFAULT 'routine',
    `is_armed`      TINYINT(1)   NOT NULL DEFAULT 0,
    `is_violent`    TINYINT(1)   NOT NULL DEFAULT 0,
    `is_mentally_ill` TINYINT(1) NOT NULL DEFAULT 0,
    `notes`         TEXT         NULL,
    `status`        ENUM('active','closed') NOT NULL DEFAULT 'active',
    `issued_by`     VARCHAR(64)  NOT NULL,
    `issued_by_id`  INT UNSIGNED NULL,
    `signature`     VARCHAR(64)  NULL,
    `department`    VARCHAR(16)  NOT NULL,
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at`     DATETIME     NULL,
    PRIMARY KEY (`id`),
    KEY `idx_status` (`status`),
    KEY `idx_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `x1s_ten_codes` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `code`          VARCHAR(16)  NOT NULL,
    `label`         VARCHAR(128) NOT NULL,
    `sort_order`    INT          NOT NULL DEFAULT 0,
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_ten_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `x1s_penal_codes` (
    `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `code`          VARCHAR(32)  NOT NULL,
    `title`         VARCHAR(128) NOT NULL,
    `type`          VARCHAR(16)  NOT NULL DEFAULT 'Misdemeanor',
    `bond_type`     VARCHAR(32)  NOT NULL DEFAULT 'Personal Recognizance',
    `bond_amount`   INT UNSIGNED NOT NULL DEFAULT 0,
    `jail_time`     VARCHAR(64)  NOT NULL DEFAULT '',
    `sort_order`    INT          NOT NULL DEFAULT 0,
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_penal_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `x1s_vehicle_history` (
    `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `vehicle_id`      INT UNSIGNED NOT NULL,
    `event_type`      VARCHAR(24)  NOT NULL,
    `details`         VARCHAR(255) NULL,
    `performed_by`    VARCHAR(64)  NULL,
    `performed_by_id` INT UNSIGNED NULL,
    `created_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_vehicle` (`vehicle_id`),
    CONSTRAINT `fk_vehicle_history_vehicle` FOREIGN KEY (`vehicle_id`) REFERENCES `x1s_vehicles` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- MIGRATION
ALTER TABLE `x1s_vehicles` ADD COLUMN IF NOT EXISTS `brand` VARCHAR(32) NULL AFTER `plate`;
ALTER TABLE `x1s_vehicles` ADD COLUMN IF NOT EXISTS `vehicle_type` VARCHAR(32) NULL AFTER `brand`;
ALTER TABLE `x1s_vehicles` ADD COLUMN IF NOT EXISTS `plate_state` VARCHAR(8) NULL AFTER `plate`;
ALTER TABLE `x1s_vehicles` ADD COLUMN IF NOT EXISTS `vehicle_year` SMALLINT UNSIGNED NULL AFTER `vehicle_type`;
ALTER TABLE `x1s_vehicles` ADD COLUMN IF NOT EXISTS `registration_date` DATE NULL AFTER `registration`;
ALTER TABLE `x1s_vehicles` ADD COLUMN IF NOT EXISTS `expiration_date` DATE NULL AFTER `registration_date`;
ALTER TABLE `x1s_vehicles` ADD COLUMN IF NOT EXISTS `retired_at` DATETIME NULL AFTER `stolen`;

ALTER TABLE `x1s_arrests` ADD COLUMN IF NOT EXISTS `signature` VARCHAR(64) NULL AFTER `assisting`;

ALTER TABLE `x1s_citations` MODIFY COLUMN `violation` VARCHAR(128) NULL;
ALTER TABLE `x1s_citations` MODIFY COLUMN `fine` INT UNSIGNED NULL DEFAULT 0;
ALTER TABLE `x1s_citations` ADD COLUMN IF NOT EXISTS `violations` LONGTEXT NULL AFTER `fine`;
ALTER TABLE `x1s_citations` ADD COLUMN IF NOT EXISTS `fine_total` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `violations`;
ALTER TABLE `x1s_citations` ADD COLUMN IF NOT EXISTS `signature` VARCHAR(64) NULL AFTER `fine_total`;

ALTER TABLE `x1s_warrants` ADD COLUMN IF NOT EXISTS `charges` LONGTEXT NULL AFTER `reason`;
ALTER TABLE `x1s_warrants` ADD COLUMN IF NOT EXISTS `signature` VARCHAR(64) NULL AFTER `issued_by_id`;

ALTER TABLE `x1s_vehicle_bolos` ADD COLUMN IF NOT EXISTS `priority` VARCHAR(16) NOT NULL DEFAULT 'routine' AFTER `reason`;
ALTER TABLE `x1s_vehicle_bolos` ADD COLUMN IF NOT EXISTS `signature` VARCHAR(64) NULL AFTER `issued_by_id`;
ALTER TABLE `x1s_vehicle_bolos` ADD COLUMN IF NOT EXISTS `is_armed` TINYINT(1) NOT NULL DEFAULT 0 AFTER `priority`;
ALTER TABLE `x1s_vehicle_bolos` ADD COLUMN IF NOT EXISTS `is_violent` TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_armed`;
ALTER TABLE `x1s_vehicle_bolos` ADD COLUMN IF NOT EXISTS `is_mentally_ill` TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_violent`;

ALTER TABLE `x1s_characters` ADD COLUMN IF NOT EXISTS `is_armed` TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_dead`;
ALTER TABLE `x1s_characters` ADD COLUMN IF NOT EXISTS `is_violent` TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_armed`;
ALTER TABLE `x1s_characters` ADD COLUMN IF NOT EXISTS `is_mentally_ill` TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_violent`;
ALTER TABLE `x1s_characters` ADD COLUMN IF NOT EXISTS `address` VARCHAR(96) NULL AFTER `licenses`;

ALTER TABLE `x1s_warrants` ADD COLUMN IF NOT EXISTS `is_armed` TINYINT(1) NOT NULL DEFAULT 0 AFTER `signature`;
ALTER TABLE `x1s_warrants` ADD COLUMN IF NOT EXISTS `is_violent` TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_armed`;
ALTER TABLE `x1s_warrants` ADD COLUMN IF NOT EXISTS `is_mentally_ill` TINYINT(1) NOT NULL DEFAULT 0 AFTER `is_violent`;

ALTER TABLE `x1s_incidents` ADD COLUMN IF NOT EXISTS `signing_officer` VARCHAR(64) NULL AFTER `evidence`;
