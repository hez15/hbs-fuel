CREATE TABLE IF NOT EXISTS `hbs_fuel_vehicle_state` (
  `plate` VARCHAR(16) NOT NULL,
  `litres` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hbs_fuel_station_stock` (
  `station_id` VARCHAR(64) NOT NULL,
  `fuel_type` VARCHAR(32) NOT NULL,
  `current_litres` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `max_litres` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`station_id`, `fuel_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hbs_fuel_refinery_crude` (
  `refinery_id` VARCHAR(64) NOT NULL,
  `current_litres` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `max_litres` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`refinery_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hbs_fuel_refinery_stock` (
  `refinery_id` VARCHAR(64) NOT NULL,
  `fuel_type` VARCHAR(32) NOT NULL,
  `current_litres` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `max_litres` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`refinery_id`, `fuel_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hbs_fuel_tanker_state` (
  `plate` VARCHAR(16) NOT NULL,
  `fuel_type` VARCHAR(32) NULL,
  `litres` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `max_litres` DECIMAL(12,2) NOT NULL DEFAULT 12000.00,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `hbs_fuel_contracts` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `contract_id` VARCHAR(64) NOT NULL,
  `type` VARCHAR(32) NOT NULL,
  `product` VARCHAR(32) NOT NULL,
  `pickup_type` VARCHAR(64) NOT NULL,
  `pickup_id` VARCHAR(64) NOT NULL,
  `dropoff_type` VARCHAR(64) NOT NULL,
  `dropoff_id` VARCHAR(64) NOT NULL,
  `litres_required` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `litres_delivered` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `payout` INT NOT NULL DEFAULT 0,
  `urgency` VARCHAR(16) NOT NULL DEFAULT 'normal',
  `status` VARCHAR(16) NOT NULL DEFAULT 'available',
  `accepted_by` INT NULL DEFAULT NULL,
  `expires_at` DATETIME NULL DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_hbs_fuel_contracts_contract_id` (`contract_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `hbs_fuel_ownership` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `entity_type` ENUM('station', 'refinery') NOT NULL,
  `entity_id` VARCHAR(64) NOT NULL,
  `owner_identifier` VARCHAR(64) DEFAULT NULL,
  `owner_name` VARCHAR(128) DEFAULT NULL,
  `purchase_price` INT NOT NULL DEFAULT 0,
  `purchased_at` TIMESTAMP NULL DEFAULT NULL,
  `revenue_total` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `revenue_withdrawn` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_hbs_fuel_ownership_entity` (`entity_type`, `entity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
