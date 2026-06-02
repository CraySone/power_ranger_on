Power Ranger ON
===============

Compact ArcheAge Classic PvP overlay for target role icons, armor/weapon buff icons, target intel, ownership info, and self cooldown tracking.

Version: 1.0.5

Nuzi UI compatibility
---------------------

Power Ranger ON includes a compatibility mode for running beside Nuzi UI.

- `Compat Auto` detects Nuzi UI settings through the public addon API and hides duplicate Power Ranger surfaces.
- `Compat On` forces the same duplicate-hiding behavior while Nuzi UI is detected.
- `Compat Off` leaves Power Ranger ON fully independent.

When compatibility is active, Power Ranger ON keeps its unique armor, weapon, role, and ownership overlays, but hides duplicate target text, the normal target intel window, and the self cooldown panel.

Nuzi-specific settings only appear when Nuzi UI or its legacy `polar-ui` settings are detected from saved settings or the public addon settings table.

Cooldown import
---------------

The self cooldown panel can import learned mount and glider cooldowns from `nuzi-ui/.data/mount_glider_devices.txt`. The `Nuzi CDs` settings toggle controls this runtime import.
