CREATE TABLE `documents` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`opensearch_id` text NOT NULL,
	`file_id` integer NOT NULL,
	FOREIGN KEY (`file_id`) REFERENCES `files`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `files` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`scan_id` text NOT NULL,
	`ino` integer NOT NULL,
	`mtime_ms` integer NOT NULL,
	`ctime_ms` integer NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `documents_opensearch_id_unique` ON `documents` (`opensearch_id`);--> statement-breakpoint
CREATE INDEX `opensearch_id_idx` ON `documents` (`opensearch_id`);--> statement-breakpoint
CREATE UNIQUE INDEX `files_ino_unique` ON `files` (`ino`);--> statement-breakpoint
CREATE INDEX `ino_idx` ON `files` (`ino`);--> statement-breakpoint
CREATE INDEX `scan_id_idx` ON `files` (`scan_id`);