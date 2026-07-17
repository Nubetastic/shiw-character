-- Optional manual installation; rsg-clothingstore also creates this table when missing.
CREATE TABLE IF NOT EXISTS `playerclothes` (
    `citizenid` VARCHAR(50) NOT NULL,
    `bought` LONGTEXT NOT NULL,
    `outfit` LONGTEXT NOT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
