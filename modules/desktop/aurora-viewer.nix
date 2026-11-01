{
  config,
  lib,
  ...
}: {
  overlays.aurora-viewer = final: _prev: {
    aurora-viewer = final.callPackage ../../packages/aurora-viewer/package.nix {};
  };
  perSystem = {pkgs, ...}:
    lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      packages.aurora-viewer = pkgs.aurora-viewer;
    };

  home.lisa-vega.imports = [config.home.aurora-viewer];
  home.aurora-viewer = {pkgs, ...}: {
    home.packages = [pkgs.aurora-viewer];
  };

  home.lisa-vega.forge.mutablePreferences = {
    "Library/Application Support/org.Aurora.AuroraViewer/settings.json" = {
      settings = {
        update_mode = "Ask";
        update_channel = "Stable";
        ignored_update = "";
        crash_reports = "Ask";
        language = "default";
        language_is_public = true;
        show_bug_report = true;
        show_huds = true;
        sun_beacon = false;
        moon_beacon = false;
        beacons = {
          lines = false;
          highlights = true;
          info = true;
          width = 1;
          scripted = false;
          touch = false;
          physical = false;
          sound = false;
          particles = false;
          media = false;
        };
        world_overlays = {
          property_lines = false;
        };
        build = {
          layout = {
            order = [
              "manipulators"
              "face"
              "stretchTextures"
              "linked"
              "scaleBoth"
              "rootAxis"
              "snap"
              "highlight"
              "probes"
              "landGroup"
              "followEdit"
              "actions"
              "nav-section-general"
              "nav-section-shape"
              "nav-section-materials"
              "nav-section-features"
              "nav-section-contents"
              "nav-tool-camera"
              "nav-tool-grab"
              "nav-tool-edit"
              "nav-tool-create"
              "nav-tool-land"
            ];
          };
          transform_expanded = true;
          color_picker = {
            apply = true;
            palette = [
              [
                0.0
                0.0
                0.0
              ]
              [
                0.5
                0.5
                0.5
              ]
              [
                0.5
                0.0
                0.0
              ]
              [
                0.5
                0.5
                0.0
              ]
              [
                0.0
                0.5
                0.0
              ]
              [
                0.0
                0.5
                0.5
              ]
              [
                0.0
                0.0
                0.5
              ]
              [
                0.5
                0.0
                0.5
              ]
              [
                0.5
                0.5
                0.0
              ]
              [
                0.0
                0.25
                0.25
              ]
              [
                0.0
                0.5
                1.0
              ]
              [
                0.0
                0.25
                0.5
              ]
              [
                0.5
                0.0
                1.0
              ]
              [
                0.5
                0.25
                0.0
              ]
              [
                1.0
                1.0
                1.0
              ]
              [
                1.0
                1.0
                1.0
              ]
              [
                1.0
                1.0
                1.0
              ]
              [
                0.75
                0.75
                0.75
              ]
              [
                1.0
                0.0
                0.0
              ]
              [
                1.0
                1.0
                0.0
              ]
              [
                0.0
                1.0
                0.0
              ]
              [
                0.0
                1.0
                1.0
              ]
              [
                0.0
                0.0
                1.0
              ]
              [
                1.0
                0.0
                1.0
              ]
              [
                1.0
                1.0
                0.5
              ]
              [
                0.0
                1.0
                0.5
              ]
              [
                0.5
                1.0
                1.0
              ]
              [
                0.5
                0.5
                1.0
              ]
              [
                1.0
                0.0
                0.5
              ]
              [
                1.0
                0.5
                0.0
              ]
              [
                1.0
                1.0
                1.0
              ]
              [
                1.0
                1.0
                1.0
              ]
            ];
          };
          grid_resolution = 0.5;
          grid_draw_size = 12.0;
          grid_sub_unit = false;
          grid_opacity = 0.7;
          grid_mode = 0;
          snap = true;
          rotation_step = 1.0;
          edit_linked = false;
          scale_uniform = false;
          scale_stretch_textures = true;
          follow_edit_object = false;
          show_highlight = true;
          create_shape = 0;
          keep_tool = false;
          rez_under_land_group = true;
          new_prim_size = [
            0.5
            0.5
            0.5
          ];
          new_prim_material = 3;
          land_action = 6;
          land_brush_size = 2.0;
          land_brush_force = 1.0;
          actual_root = false;
          decimal_precision = 5;
          copy_selection = false;
          copy_centers = true;
          copy_rotates = false;
          expanded = true;
          show_parcel_owners = false;
          sync_materials = false;
          show_physics_shape = false;
          copy_key_separator = ",";
          limit_select_distance = false;
          max_select_distance = 128.0;
          limit_drag_distance = true;
          max_drag_distance = 48.0;
          gizmo_scale = 1.0;
        };
        camera = {
          preset = "Rear";
          camera_offset = [
            (-3.0)
            0.0
            0.75
          ];
          focus_offset = [
            1.0
            0.0
            1.0
          ];
          offset_scale = 1.0;
          fov = 1.0471976;
          zoom_time = 0.4;
          smoothing = 1.0;
          dynamic_strength = 2.0;
          disable_constraints = true;
          ignore_sim_constraints = true;
          disable_wheel_zoom = false;
          click_avatar_keeps_camera = false;
          reset_on_movement = true;
          reset_on_teleport = true;
          reset_view_turns_avatar = false;
          hover_affects_camera = false;
          track_focus_object = true;
          enable_mouselook = true;
          show_avatar_in_mouselook = false;
          mouselook_follow_eyes = false;
          wheel_exits_mouselook = true;
          mouselook_zoom_fov = null;
          mouselook_alt_right_menu = false;
          show_mouselook_instructions = true;
          show_interface_in_mouselook = false;
        };
        crosshair = {
          show = true;
          shape = "dot";
          size = 16.0;
          dot_size = 4.0;
          thickness = 2.0;
          gap = 6.0;
          center_dot = false;
          color = [
            255
            255
            255
            230
          ];
          outline = true;
        };
        joystick = {
          enabled = false;
          device = "";
          avatar_enabled = true;
          flycam_enabled = true;
          mapping = [
            1
            0
            2
            4
            3
            5
            (-1)
          ];
          avatar = {
            gain = [
              1.0
              1.0
              1.0
              0.0
              0.1
              0.1
              0.0
            ];
            dead_zone = [
              0.1
              0.1
              0.1
              1.0
              0.02
              0.01
              1.0
            ];
            feather = 6.0;
          };
          flycam = {
            gain = [
              2.1
              2.0
              2.0
              0.0
              0.1
              0.15
              0.0
            ];
            dead_zone = [
              0.01
              0.01
              0.01
              0.01
              0.01
              0.01
              0.01
            ];
            feather = 5.0;
          };
          auto_level = true;
          direct_zoom = false;
          mouselook_yaw = false;
          run_threshold = 0.7;
          flycam_button = 0;
          jump_button = 1;
          rise_button = -1;
          fall_button = -1;
        };
        auto_hover_height = false;
        auto_hover_offset = 0.0;
        contacts = {
          torn_off = false;
          show_search = true;
          column_display_name = false;
          column_full_name = true;
          column_permissions = true;
          sort_by_display_name = false;
          full_name_display_first = true;
          set_list_icons = true;
          tab = 0;
        };
        radar = {
          columns = 1023;
          show_minimap = false;
          limit_range = false;
          range = 162.0;
          show_muted = true;
          name_format = 0;
          color_names = false;
          toasts = false;
          chat_enter = false;
          chat_leave = false;
          draw_enter = false;
          draw_leave = false;
          enter_scripts = false;
          leave_scripts = false;
          script_channel = -777777777;
          enhance_by_bridge = true;
          age_alert = false;
          age_alert_days = 7;
          sort = 9;
          sort_descending = false;
          compact = false;
        };
        texture_library = {
          presentation = "Vertical";
          texture_preview_size = null;
          material_preview_size = null;
          texture_display = {
            actual_size = false;
            keep_ratio = true;
            ratio = 0;
            custom_ratio = [
              1.0
              1.0
            ];
          };
        };
        gestures = {};
        imports = {
          max_width = 1024;
          max_height = 1024;
          limit_texture_size = false;
          lossless_small = true;
          next_modify = false;
          next_copy = false;
          next_transfer = true;
          share_group = false;
          everyone_copy = false;
          permissions_by_type = {
            texture = null;
            sound = null;
            animation = null;
            mesh = null;
            material = null;
          };
          show_payment = true;
          preview_on_avatar = false;
          mesh_auto_weights = true;
          mesh_auto_preview_weights = true;
          mesh_reliable_default = false;
          mesh_model_limit = 768;
          mesh_upload_timeout = 600;
          mesh_suffixes = [
            "LOD0"
            "LOD1"
            "LOD2"
            ""
            "PHYS"
          ];
          mesh_physics_preset = "";
          local_assume_meters = false;
          local_mesh_auto_reload = false;
          local_reload_seconds = 3.0;
          preview_background = null;
          preview_edges = null;
          preview_physics_fill = null;
          preview_physics_edges = null;
          preview_degenerate_fill = null;
          preview_degenerate_edges = null;
        };
        ao = {};
        bridge = {
          "518d9b42-dcc0-40d7-bc91-082942bf7f25" = {
            enabled = false;
            indicator = false;
            mode = "bridge";
          };
        };
        movements = {
          "518d9b42-dcc0-40d7-bc91-082942bf7f25" = {
            running = false;
            fly_assist = false;
            swimming = false;
            water_walk = false;
            water_jumps = true;
            pass_wall = false;
            jump_obstacles = true;
            run_multiplier = 1.0;
            swim_speed = 5.0;
            fly_multiplier = 1.0;
            float_height = 0.0;
            style = "Breaststroke";
            discover_strokes = [
              true
              true
              true
            ];
            controller_version = 6;
          };
        };
        snapshot = {
          aspect = "Window";
          resolution = "Uhd";
          custom = [
            1920
            1080
          ];
          keep_ratio = true;
          format = "Png";
          jpeg_quality = 75;
          interface = false;
          huds = false;
          auto_refresh = false;
          base_name = "Snapshot";
          guide = "Thirds";
          sound = true;
          profile_size = "S640";
          profile_location = true;
          postcard_size = "S800";
          dof = {
            enabled = true;
            f_number = 2.8;
            focus = "Click";
            distance = 5.0;
          };
          quality = false;
          viewfinder = {
            display = "Full";
            area = "Avatar";
            peaking = "White";
            beep = true;
            hints = true;
            controls = "Always";
            pad = false;
            timer = 0;
            dof_defaulted = false;
          };
          looks = [];
          look_settings = {};
        };
        dof = {
          enabled = false;
          in_edit = false;
          focus = "Camera";
          f_number = 9.0;
          focal_length = 50.0;
          reference_fov = 60.0;
          max_coc = 10.0;
          transition = 0.5;
          quality = 0.7;
        };
        shape_show_hints = true;
        shape_height_feet = false;
        customize_animation = true;
        script_editor = {
          colors = {};
          font_size = 13.0;
          word_wrap = true;
          search_prefer_left = false;
          search_inline = false;
          convert_tabs = true;
          preprocessor = false;
          optimize = true;
          switches = true;
          lazy_lists = true;
          disk_includes = false;
          owner_say_debug = false;
          recompile = false;
          external_editor = "";
          help_follows_cursor = false;
        };
        grid = "SecondLife";
        grids = [];
        start_location = "last";
        start_region = "";
        draw_distance = 128.0;
        gpu_driver_dismissed = "";
        allow_overlays = false;
        vsync = false;
        shadows = false;
        force_midday = false;
        time_of_day = 0;
        env_manual_transition = 0.0;
        env_persist = true;
        exposure = 1.0;
        sharpen = 0.0;
        glow = true;
        bloom = false;
        bloom_strength = 0.5;
        occlusion_culling = true;
        lod_factor = 2.0;
        texture_budget_auto = false;
        texture_budget_mb = 10000;
        ui_scale = 1.0;
        use_pie_menu = false;
        world_context_menus = {
          profiles = {
            "scene:attachment" = {
              layout = {
                placements = {};
                orders = {};
                slots = {};
                groups = {};
                icon_bars = [];
                directions = {};
                separators = {};
                removed = [];
                filters = [];
              };
              open = {};
              locked = true;
            };
            "scene:avatar" = {
              layout = {
                placements = {};
                orders = {};
                slots = {};
                groups = {};
                icon_bars = [];
                directions = {};
                separators = {};
                removed = [];
                filters = [];
              };
              open = {};
              locked = true;
            };
            "scene:hud" = {
              layout = {
                placements = {};
                orders = {};
                slots = {};
                groups = {};
                icon_bars = [];
                directions = {};
                separators = {};
                removed = [];
                filters = [];
              };
              open = {};
              locked = true;
            };
          };
        };
        particle_filters = {
          objects = [];
          owners = [];
        };
        snap_windows = true;
        show_perf = false;
        show_chat = true;
        show_minimap = false;
        standalone_place_details = false;
        inspect_columns = 1023;
        confirm_teleports = true;
        confirm_no_transfer_settings = true;
        confirm_object_bonus = true;
        confirm_return_to_owner = true;
        confirm_attachment_drop = true;
        confirm_script_modify = true;
        confirm_payments = true;
        payment_confirm_threshold = 200;
        always_track_payments = false;
        payment_opens_conversation = true;
        maps = {
          mini_scale = 128.0;
          mini_rotate = false;
          mini_objects = true;
          mini_physical = false;
          mini_scripted = false;
          mini_temp_on_rez = false;
          mini_property_lines = true;
          mini_for_sale = false;
          mini_collision = true;
          mini_auto_center = true;
          mini_double_click = 2;
          world_scale = 128.0;
          world_people = true;
          world_infohubs = true;
          world_telehubs = true;
          world_land_for_sale = true;
          world_events = true;
          world_mature_events = true;
          world_adult_events = false;
          world_grid_coords = false;
          world_double_click_tp = true;
          ban_lines = 1;
        };
        search = {
          group_maturity = 13;
          places = {
            pg = true;
            mature = false;
            adult = false;
          };
          land = {
            pg = true;
            mature = false;
            adult = false;
          };
          events = {
            pg = true;
            mature = false;
            adult = false;
          };
          classifieds = {
            pg = true;
            mature = false;
            adult = false;
          };
          land_limit_price = true;
          land_limit_area = false;
          land_type = 0;
          teleport_action = 1;
          aurora_ratings = {
            pg = true;
            mature = false;
            adult = false;
          };
        };
        show_people = true;
        people_tab = 0;
        show_appearance = false;
        appearance_fill_previews = false;
        show_ao = false;
        loading_backdrop = true;
        mouse_sensitivity = 1.0;
        font = "Inter";
        font_scale = 1.0;
        show_chat_channel = false;
        script_errors_in_chat = true;
        script_errors_to_channel = false;
        script_errors_channel = 1;
        compact_automated_chat = false;
        compact_im_system_lines = false;
        chat_keep_focus = true;
        chat_gesture_autocomplete = true;
        chat_name_prediction = true;
        colon_emote = false;
        chat_mention_autocomplete = true;
        autohide_chat_bar = false;
        show_contacts_tab = true;
        conversations_own_windows = false;
        send_typing_state = true;
        play_typing_anim = true;
        type_during_emote = false;
        typing_in_name_tags = true;
        typing_chevron = false;
        chat_bubbles = false;
        chat_bubbles_hide_console = true;
        typing_bubbles = false;
        chat_bubble_opacity = 0.5;
        flash_unread_conversations = true;
        flash_conversations_button = true;
        flash_conversations_nearby = true;
        chat_thumbnails = "ChatBar";
        chat_thumbnails_flash = true;
        flash_on_message = true;
        flash_on_object_im = true;
        flash_on_script_dialog = false;
        system_notifications = false;
        system_notifications_when_active = false;
        chat_toast_seconds = 20.0;
        presence_position = "TopRight";
        toast_im = true;
        toast_group_im = false;
        ims_in_notification_center = false;
        im_toast_seconds = 30.0;
        log_im = true;
        log_nearby = false;
        reopen_ims = false;
        log_dated_names = false;
        warn_external_links = true;
        trusted_sites = {
          added = [];
          removed = [];
        };
        mute_all_groups = false;
        mute_groups_without_notices = false;
        group_snooze_minutes = 15;
        group_snooze_ask = false;
        report_blocks = false;
        show_joined_group_invitations = false;
        script_count_alert = false;
        script_count_threshold = 100;
        sim_version_alert = true;
        object_im_filter = {
          on = false;
          scope = "Region";
        };
        anti_spam = {
          enabled = false;
          own_objects = false;
          global = false;
          period = 4;
          amount = 10;
          newlines = 70;
          sound_multiplier = 6;
          preload_multiplier = 6;
        };
        rlva_enabled = true;
        rlva = {
          im_queries = true;
          im_queries_auto_share = false;
          allow_shared_offers = true;
          allow_environment_locks = true;
          temporary_controllers = true;
          experience_maturity = 2;
          allow_ooc = true;
          show_ellipsis = true;
          split_redirect_chat = false;
          show_redirect_typing = false;
          replace_unlocked = true;
          experimental_commands = true;
          debug_commands = false;
          debug_hide_unset_duplicate = false;
          compatibility_list = "";
          legacy_naming = true;
          shared_wear = true;
          auto_rename = true;
          hide_locked_attachments = false;
          hide_locked_layers = false;
          wear_add_prefix = "+";
          wear_replace_prefix = "";
        };
        pose_requests = {
          policy = "Friends";
          blocked = [];
        };
        poser = {
          stop_on_close = true;
          markers = true;
          natural = true;
          dof = false;
          sensitivity = 0.5;
          also_bvh = false;
          unlock_pelvis = false;
          confirm_overwrite = false;
          confirm_close = true;
        };
        autoresponse = {
          autorespond = false;
          reject_teleports = false;
          reject_group_invites = false;
          ignore_adhoc = false;
          report_ignored_adhoc = false;
          dnd_text = "This resident has enabled Do Not Disturb and will see your message later.";
          autorespond_text = "The resident you messaged has enabled Aurora Viewer's auto-response mode and does not want to be disturbed. Your message will still appear in their IM window for later reading.";
          send_away = false;
          away_text = "The resident you messaged is away. Your message will appear in their IM window for later reading.";
          send_muted = false;
          muted_text = "The resident you messaged has blocked all messages from you.";
          reject_teleports_text = "The resident you messaged has enabled Aurora Viewer's mode that rejects all teleport offers and requests. They do not want to be disturbed by teleport requests, but you can still send them an IM.";
          away_after_minutes = 0;
          sit_when_away = false;
          quit_after_away_minutes = 0;
        };
        chat_commands = {
          enabled = true;
          calc = "calc";
          draw_distance = "dd";
          bandwidth = "bw";
          copy_cam = "cpcampos";
          paste_cam = "pstcampos";
          ao = "cao";
          clear_chat = "clrchat";
          media = "/media";
          music = "/music";
          rez_platform = "rezplat";
          platform_size = 30.0;
          key_to_name = "key2name";
          roll_dice = "rolld";
          track_pos = "trkpos";
          pos = "gtp";
          ground = "flr";
          height = "gth";
          teleport_to_cam = "tp2cam";
          offer_tp = "offertp";
          tp2 = "tp2";
          teleport_home = "tph";
          map_to = "mapto";
          map_to_keep_pos = false;
          announce_to_channel = false;
          announce_channel = 362395;
        };
        keywords = {
          on = false;
          in_chat = false;
          in_im = false;
          speakers_name = false;
          case_sensitive = false;
          whole_words = false;
          words = "";
          change_color = false;
          color = [
            255
            153
            0
            255
          ];
          play_sound = false;
        };
        spelling = {
          enabled = true;
          main = "en_us";
          extra = [
            "sl"
          ];
        };
        auto_replace = false;
        name_tag_distance = 64.0;
        show_own_name_tag = true;
        show_other_name_tags = true;
        temporary_name_tags = false;
        name_tag_show_seconds = 10.0;
        classic_name_tags = false;
        plates_hover_expand = true;
        plates_jiggle = false;
        plates_click_combo = false;
        plate_click = "Nothing";
        plate_shift_click = "Nothing";
        plate_ctrl_click = "Nothing";
        classic_profiles = false;
        profile_rights = true;
        classic_pay_window = false;
        legacy_money_tracker = false;
        classic_bars = false;
        place_bar_stretch = true;
        place_bar_rights_text = false;
        system_island = {
          clock = true;
          ping = true;
          fps = true;
          media = true;
          clock_zone = "Slt";
          clock_seconds = true;
          clock_format = "Auto";
        };
        confirm_hide_interface = true;
        immersive_name_tags = false;
        immersive_huds = true;
        show_net_stats = false;
        show_balance = true;
        classic_people = false;
        classic_restart_alert = false;
        classic_chat_lines = false;
        classic_rez_effect = false;
        hover_tips = {
          enabled = false;
          form = "Card";
          all_objects = false;
          land = false;
          group_titles = true;
          delay = 0.35;
        };
        classic_hover_tips = false;
        predict_own_motion = false;
        synchronize_animations = false;
        sort_received_items = false;
        received_items_since = 0;
        notify_deliveries = true;
        ground_avatar_feet = false;
        ground_feet_while_moving = false;
        ground_feet_max_height = 0.4;
        ground_feet_max_avatars = 5;
        collisions = {
          in_chat = false;
          report = false;
          channel = -25000;
        };
        reduce_motion = false;
        color_blindness = "Off";
        color_blindness_strength = 1.0;
        high_contrast = false;
        interface_colors = {
          accent = null;
          surface = null;
          text = null;
        };
        classic_controls = false;
        camera_shots = [];
        chat_style = "Aurora";
        link_previews = {
          ims = true;
          groups = true;
          nearby = false;
          blur_groups = true;
          load = "Trusted";
          player = "InCard";
          size = "Medium";
          hidden_sites = [];
          picture_sites = [];
          video_volume = 1.0;
          subtitles = false;
          subtitle_language = "";
        };
        gifs = {
          show_button = false;
          hidden_by_user = false;
          provider = "Giphy";
          rating = "Moderate";
          giphy_key = "";
          klipy_key = "";
          customer_id = "";
        };
        notifications_style = "Aurora";
        world_map_style = "Aurora";
        photo_window = "Aurora";
        classic_about_land = false;
        classic_search = false;
        classic_region_estate = false;
        classic_places = false;
        places_sort = "Visit";
        invert_mouse = false;
        world_mouse_walk = false;
        arrows_strafe = false;
        arrow_keys_always_move = false;
        letter_keys_move = true;
        walk_backwards_without_turning = false;
        automatic_fly = false;
        automatic_land = true;
        fly_after_teleport = false;
        crouch_toggle = false;
        quickjump = false;
        block_click_sit = false;
        double_click = "Nothing";
        follow = {
          distance = 2.0;
          teleport_if_stuck = false;
        };
        lookat = {
          show_targets = false;
          show_names = 1;
          hide_own = true;
          lines = false;
          private = false;
          private_local = false;
          private_point_at = false;
          limit_distance = false;
          max_distance = 1.0;
          head_yaw = 90.0;
          head_pitch = 90.0;
          static_eyes = false;
          style = "Aurora";
          aim = "Point";
        };
        shadow_quality = 0;
        projector_shadows = false;
        contact_shadows = false;
        antialiasing = 1;
        render_scale_percent = 50;
        specular_aa = true;
        tonemapper = 1;
        tonemap_mix = 0.7;
        hdr_emissive = true;
        fps_cap = true;
        fps_limit = 120;
        background_fps_cap = true;
        background_fps_limit = 15;
        max_particles = 4096;
        max_avatars = 19;
        ssao = 1;
        ao_method = 1;
        gtao_quality = 0;
        water_effects = {
          enabled = false;
          quality = 1;
          waves = true;
          absorption = true;
          fresnel = true;
          wet_ground = true;
          shore_foam = true;
          contact_foam = true;
          crest_foam = true;
          interactions = true;
          caustics = true;
          splashes = true;
          bubbles = true;
        };
        screen_indirect_light = false;
        screen_indirect_intensity = 1.5;
        water_reflections = 0;
        mirrors = 0;
        reflection_probes = 2;
        probe_count = 32;
        max_complexity = 0;
        max_attachment_area = 1000.0;
        loading_avatars = 0;
        complexity_mode = 1;
        avatar_physics = true;
        avatar_physics_detail = 1.0;
        render_exceptions = [];
        tag_complexity = true;
        tag_complexity_too_complex_only = true;
        tag_complexity_own = false;
        use_display_names = true;
        group_titles = "All";
        trim_resident = true;
        display_name_notices = true;
        ssr = false;
        anisotropy = 8;
        chat_log_location = "";
        bandwidth_kbps = 4000;
        no_neighbour_regions = false;
        parcel_visibility = {
          mode = "Off";
          same_owner = false;
          same_group = false;
          parcels = [];
          always_visible = [];
        };
        chat_bar_width = 0.0;
        chat_island_width = 0.0;
        toolbar_common = {
          buttons = null;
          locked = false;
          bottom_style = {
            mode = null;
            align = null;
            sizing = null;
          };
          left_style = {
            mode = null;
            align = null;
            sizing = null;
          };
          right_style = {
            mode = null;
            align = null;
            sizing = null;
          };
        };
        audio = {
          explorer = {
            avatars = false;
            objects = true;
            collisions = false;
            repeats = false;
          };
          voice_ear = "Camera";
          voice_automatic_gain = true;
          voice_echo_cancellation = true;
          voice_noise_suppression = 4;
          lip_sync = true;
          voice_visualizer = true;
          voice_visualizer_self = true;
          voice_visualizer_dot = true;
          voice_visualizers_in_calls = true;
          conversation_voice_indicator = true;
          volume = [
            0.8
            0.5
            0.5
            0.5
            0.4
            0.5
            0.7
          ];
          perceptual_volume = false;
          muted = [
            false
            false
            false
            false
            false
            false
            false
          ];
          enabled = [
            true
            true
            true
            true
            true
            true
            true
          ];
          music_autoplay = false;
          media_autoplay = false;
          stream_title = "Chat";
          stream_title_announce = false;
          stream_title_channel = 362394;
          stream_title_window = false;
          stream_title_text_only = false;
          mute_when_minimized = false;
          output_device = "";
          input_device = "";
          voice_enabled = false;
          mic_hold = false;
          mic_gain = 1.0;
          collision_sounds = true;
          gesture_sounds = true;
          ui_sounds = true;
          ui = {
            play = {};
            im_mode = "NewSession";
            group_mode = "NewSession";
            conf_mode = "NewSession";
            money_threshold = 50.0;
          };
          saved_streams = [];
          reject_group_calls = false;
          reject_adhoc_calls = false;
          reject_p2p_calls = false;
        };
        media = {
          enabled = true;
          prim_media = true;
          show_on_others = false;
          max_instances = 8;
          allow_scripted = false;
          autoplay_huds = true;
          filter = true;
          filter_trust_own_worn = true;
          filter_explained = false;
          plugin_dir = "";
        };
        colors = {
          relation_names = true;
          tag_me = [
            255
            255
            255
            255
          ];
          tag_muted = [
            111
            123
            160
            255
          ];
          tag_linden = [
            244
            114
            182
            255
          ];
          tag_match = [
            232
            237
            251
            255
          ];
          tag_mismatch = [
            232
            237
            251
            255
          ];
          map_me = [
            139
            92
            246
            255
          ];
          map_other = [
            74
            222
            128
            255
          ];
          map_linden = [
            244
            114
            182
            255
          ];
          map_muted = [
            111
            123
            160
            255
          ];
          map_ranges = true;
          map_whisper_on = true;
          map_say_on = true;
          map_shout_on = true;
          map_whisper = [
            108
            194
            74
            255
          ];
          map_say = [
            108
            194
            74
            255
          ];
          map_shout = [
            224
            102
            26
            255
          ];
          chat_mine = [
            154
            166
            198
            255
          ];
          chat_others = [
            232
            237
            251
            255
          ];
          chat_objects = [
            74
            222
            128
            255
          ];
          chat_linden = [
            244
            114
            182
            255
          ];
          chat_muted = [
            111
            123
            160
            255
          ];
          chat_system = [
            154
            166
            198
            255
          ];
          chat_errors = [
            248
            113
            113
            255
          ];
          chat_object_im = [
            167
            139
            250
            255
          ];
          chat_owner = [
            252
            211
            77
            255
          ];
          chat_urls = [
            94
            234
            212
            255
          ];
          chat_slurl = [
            94
            234
            212
            255
          ];
          chat_direct = [
            251
            146
            60
            255
          ];
          sender_avatar = [
            196
            181
            253
            255
          ];
          sender_object = [
            74
            222
            128
            255
          ];
          mention_text = [
            252
            211
            77
            255
          ];
          mention_residents = [
            139
            92
            246
            255
          ];
          mention_me = [
            79
            70
            229
            255
          ];
        };
        keybinds = {
          map = [
            [
              "Forward"
              [
                {
                  input = {
                    Key = "ArrowUp";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "KeyW";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "Back"
              [
                {
                  input = {
                    Key = "ArrowDown";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "KeyS";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "Left"
              [
                {
                  input = {
                    Key = "ArrowLeft";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "KeyA";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "Right"
              [
                {
                  input = {
                    Key = "ArrowRight";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "KeyD";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "StrafeLeft"
              [
                null
                null
              ]
            ]
            [
              "StrafeRight"
              [
                null
                null
              ]
            ]
            [
              "Up"
              [
                {
                  input = {
                    Key = "PageUp";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "KeyE";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "Down"
              [
                {
                  input = {
                    Key = "PageDown";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "KeyC";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "Fly"
              [
                {
                  input = {
                    Key = "Home";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "AlwaysRun"
              [
                {
                  input = {
                    Key = "KeyR";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "MoveLock"
              [
                {
                  input = {
                    Key = "KeyP";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "MovementEnhancer"
              [
                {
                  input = {
                    Key = "KeyM";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "PassWall"
              [
                null
                null
              ]
            ]
            [
              "SitGround"
              [
                {
                  input = {
                    Key = "KeyS";
                  };
                  ctrl = false;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "Mouselook"
              [
                {
                  input = {
                    Key = "KeyM";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "ResetCamera"
              [
                {
                  input = {
                    Key = "Escape";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Flycam"
              [
                {
                  input = {
                    Key = "KeyF";
                  };
                  ctrl = false;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CameraControls"
              [
                {
                  input = {
                    Key = "KeyC";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "LensZoomIn"
              [
                {
                  input = {
                    Key = "Digit0";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "Numpad0";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "LensZoomOut"
              [
                {
                  input = {
                    Key = "Digit8";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "Numpad8";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "LensZoomDefault"
              [
                {
                  input = {
                    Key = "Digit9";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "Numpad9";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "CamOrbitCw"
              [
                {
                  input = {
                    Key = "ArrowLeft";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamOrbitCcw"
              [
                {
                  input = {
                    Key = "ArrowRight";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamOrbitOver"
              [
                {
                  input = {
                    Key = "PageUp";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                {
                  input = {
                    Key = "ArrowUp";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
              ]
            ]
            [
              "CamOrbitUnder"
              [
                {
                  input = {
                    Key = "PageDown";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                {
                  input = {
                    Key = "ArrowDown";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
              ]
            ]
            [
              "CamZoomIn"
              [
                {
                  input = {
                    Key = "ArrowUp";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamZoomOut"
              [
                {
                  input = {
                    Key = "ArrowDown";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamPanLeft"
              [
                {
                  input = {
                    Key = "ArrowLeft";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamPanRight"
              [
                {
                  input = {
                    Key = "ArrowRight";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamPanUp"
              [
                {
                  input = {
                    Key = "ArrowUp";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamPanDown"
              [
                {
                  input = {
                    Key = "ArrowDown";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "Chat"
              [
                {
                  input = {
                    Key = "Enter";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "NumpadEnter";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "PushToTalk"
              [
                {
                  input = {
                    Mouse = "Middle";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "ToggleMic"
              [
                null
                null
              ]
            ]
            [
              "Conversations"
              [
                {
                  input = {
                    Key = "KeyT";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "People"
              [
                {
                  input = {
                    Key = "KeyA";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Inventory"
              [
                {
                  input = {
                    Key = "KeyI";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "TextureLibrary"
              [
                {
                  input = {
                    Key = "Space";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "IkEdit"
              [
                {
                  input = {
                    Key = "KeyK";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Gestures"
              [
                {
                  input = {
                    Key = "KeyG";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Minimap"
              [
                {
                  input = {
                    Key = "KeyM";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "WorldMap"
              [
                {
                  input = {
                    Key = "KeyM";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "TeleportHistory"
              [
                {
                  input = {
                    Key = "KeyH";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "RegionEstate"
              [
                {
                  input = {
                    Key = "KeyR";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "Search"
              [
                {
                  input = {
                    Key = "KeyF";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Performance"
              [
                {
                  input = {
                    Key = "Digit1";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Preferences"
              [
                {
                  input = {
                    Key = "KeyP";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "ToggleInterface"
              [
                {
                  input = {
                    Key = "KeyU";
                  };
                  ctrl = false;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "HoverTips"
              [
                {
                  input = {
                    Key = "KeyT";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Import"
              [
                {
                  input = {
                    Key = "KeyU";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Beacons"
              [
                {
                  input = {
                    Key = "KeyN";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "PropertyLines"
              [
                {
                  input = {
                    Key = "KeyP";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "LandOwners"
              [
                {
                  input = {
                    Key = "KeyO";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "HideParticles"
              [
                {
                  input = {
                    Key = "Equal";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "ShowHuds"
              [
                {
                  input = {
                    Key = "KeyH";
                  };
                  ctrl = false;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "HudDrag"
              [
                {
                  input = {
                    Key = "ControlLeft";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "ShowTransparency"
              [
                {
                  input = {
                    Key = "KeyT";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "Rebake"
              [
                {
                  input = {
                    Key = "KeyR";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "DevToolbox"
              [
                {
                  input = {
                    Key = "KeyD";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "StopAnimations"
              [
                {
                  input = {
                    Key = "KeyA";
                  };
                  ctrl = false;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "ResyncAnimations"
              [
                {
                  input = {
                    Key = "KeyS";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "RefreshAttachments"
              [
                {
                  input = {
                    Key = "KeyR";
                  };
                  ctrl = false;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "PhotoWindow"
              [
                {
                  input = {
                    Key = "KeyS";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "PhotoToDisk"
              [
                {
                  input = {
                    Key = "Backquote";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "EnvSunrise"
              [
                {
                  input = {
                    Key = "KeyU";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "EnvMidday"
              [
                {
                  input = {
                    Key = "KeyY";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "EnvSunset"
              [
                {
                  input = {
                    Key = "KeyN";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "EnvMidnight"
              [
                {
                  input = {
                    Key = "KeyX";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "EnvShared"
              [
                {
                  input = {
                    Key = "KeyJ";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
          ];
        };
        settings_version = 28;
      };
    };
    "Library/Application Support/org.Aurora.AuroraViewer/demo/settings.json" = {
      settings = {
        update_mode = "Ask";
        update_channel = "Stable";
        ignored_update = "";
        crash_reports = "Ask";
        language = "default";
        language_is_public = true;
        show_bug_report = true;
        show_huds = true;
        sun_beacon = false;
        moon_beacon = false;
        beacons = {
          lines = false;
          highlights = true;
          info = true;
          width = 1;
          scripted = false;
          touch = false;
          physical = false;
          sound = false;
          particles = false;
          media = false;
        };
        world_overlays = {
          property_lines = false;
        };
        build = {
          layout = {
            order = [
              "manipulators"
              "face"
              "stretchTextures"
              "linked"
              "scaleBoth"
              "rootAxis"
              "snap"
              "highlight"
              "probes"
              "landGroup"
              "followEdit"
              "actions"
              "nav-section-general"
              "nav-section-shape"
              "nav-section-materials"
              "nav-section-features"
              "nav-section-contents"
              "nav-tool-camera"
              "nav-tool-grab"
              "nav-tool-edit"
              "nav-tool-create"
              "nav-tool-land"
            ];
          };
          transform_expanded = true;
          color_picker = {
            apply = true;
            palette = [
              [
                0.0
                0.0
                0.0
              ]
              [
                0.5
                0.5
                0.5
              ]
              [
                0.5
                0.0
                0.0
              ]
              [
                0.5
                0.5
                0.0
              ]
              [
                0.0
                0.5
                0.0
              ]
              [
                0.0
                0.5
                0.5
              ]
              [
                0.0
                0.0
                0.5
              ]
              [
                0.5
                0.0
                0.5
              ]
              [
                0.5
                0.5
                0.0
              ]
              [
                0.0
                0.25
                0.25
              ]
              [
                0.0
                0.5
                1.0
              ]
              [
                0.0
                0.25
                0.5
              ]
              [
                0.5
                0.0
                1.0
              ]
              [
                0.5
                0.25
                0.0
              ]
              [
                1.0
                1.0
                1.0
              ]
              [
                1.0
                1.0
                1.0
              ]
              [
                1.0
                1.0
                1.0
              ]
              [
                0.75
                0.75
                0.75
              ]
              [
                1.0
                0.0
                0.0
              ]
              [
                1.0
                1.0
                0.0
              ]
              [
                0.0
                1.0
                0.0
              ]
              [
                0.0
                1.0
                1.0
              ]
              [
                0.0
                0.0
                1.0
              ]
              [
                1.0
                0.0
                1.0
              ]
              [
                1.0
                1.0
                0.5
              ]
              [
                0.0
                1.0
                0.5
              ]
              [
                0.5
                1.0
                1.0
              ]
              [
                0.5
                0.5
                1.0
              ]
              [
                1.0
                0.0
                0.5
              ]
              [
                1.0
                0.5
                0.0
              ]
              [
                1.0
                1.0
                1.0
              ]
              [
                1.0
                1.0
                1.0
              ]
            ];
          };
          grid_resolution = 0.5;
          grid_draw_size = 12.0;
          grid_sub_unit = false;
          grid_opacity = 0.7;
          grid_mode = 0;
          snap = true;
          rotation_step = 1.0;
          edit_linked = false;
          scale_uniform = false;
          scale_stretch_textures = true;
          follow_edit_object = false;
          show_highlight = true;
          create_shape = 0;
          keep_tool = false;
          rez_under_land_group = true;
          new_prim_size = [
            0.5
            0.5
            0.5
          ];
          new_prim_material = 3;
          land_action = 6;
          land_brush_size = 2.0;
          land_brush_force = 1.0;
          actual_root = false;
          decimal_precision = 5;
          copy_selection = false;
          copy_centers = true;
          copy_rotates = false;
          expanded = true;
          show_parcel_owners = false;
          sync_materials = false;
          show_physics_shape = false;
          copy_key_separator = ",";
          limit_select_distance = false;
          max_select_distance = 128.0;
          limit_drag_distance = true;
          max_drag_distance = 48.0;
          gizmo_scale = 1.0;
        };
        camera = {
          preset = "Rear";
          camera_offset = [
            (-3.0)
            0.0
            0.75
          ];
          focus_offset = [
            1.0
            0.0
            1.0
          ];
          offset_scale = 1.0;
          fov = 1.0471976;
          zoom_time = 0.4;
          smoothing = 1.0;
          dynamic_strength = 2.0;
          disable_constraints = true;
          ignore_sim_constraints = true;
          disable_wheel_zoom = false;
          click_avatar_keeps_camera = false;
          reset_on_movement = true;
          reset_on_teleport = true;
          reset_view_turns_avatar = false;
          hover_affects_camera = false;
          track_focus_object = true;
          enable_mouselook = true;
          show_avatar_in_mouselook = false;
          mouselook_follow_eyes = false;
          wheel_exits_mouselook = true;
          mouselook_zoom_fov = null;
          mouselook_alt_right_menu = false;
          show_mouselook_instructions = true;
          show_interface_in_mouselook = false;
        };
        crosshair = {
          show = true;
          shape = "dot";
          size = 16.0;
          dot_size = 4.0;
          thickness = 2.0;
          gap = 6.0;
          center_dot = false;
          color = [
            255
            255
            255
            230
          ];
          outline = true;
        };
        joystick = {
          enabled = false;
          device = "";
          avatar_enabled = true;
          flycam_enabled = true;
          mapping = [
            1
            0
            2
            4
            3
            5
            (-1)
          ];
          avatar = {
            gain = [
              1.0
              1.0
              1.0
              0.0
              0.1
              0.1
              0.0
            ];
            dead_zone = [
              0.1
              0.1
              0.1
              1.0
              0.02
              0.01
              1.0
            ];
            feather = 6.0;
          };
          flycam = {
            gain = [
              2.1
              2.0
              2.0
              0.0
              0.1
              0.15
              0.0
            ];
            dead_zone = [
              0.01
              0.01
              0.01
              0.01
              0.01
              0.01
              0.01
            ];
            feather = 5.0;
          };
          auto_level = true;
          direct_zoom = false;
          mouselook_yaw = false;
          run_threshold = 0.7;
          flycam_button = 0;
          jump_button = 1;
          rise_button = -1;
          fall_button = -1;
        };
        auto_hover_height = false;
        auto_hover_offset = 0.0;
        contacts = {
          torn_off = false;
          show_search = true;
          column_display_name = false;
          column_full_name = true;
          column_permissions = true;
          sort_by_display_name = false;
          full_name_display_first = true;
          set_list_icons = true;
          tab = 0;
        };
        radar = {
          columns = 1023;
          show_minimap = false;
          limit_range = false;
          range = 162.0;
          show_muted = true;
          name_format = 0;
          color_names = false;
          toasts = false;
          chat_enter = false;
          chat_leave = false;
          draw_enter = false;
          draw_leave = false;
          enter_scripts = false;
          leave_scripts = false;
          script_channel = -777777777;
          enhance_by_bridge = true;
          age_alert = false;
          age_alert_days = 7;
          sort = 9;
          sort_descending = false;
          compact = false;
        };
        texture_library = {
          presentation = "Vertical";
          texture_preview_size = null;
          material_preview_size = null;
          texture_display = {
            actual_size = false;
            keep_ratio = true;
            ratio = 0;
            custom_ratio = [
              1.0
              1.0
            ];
          };
        };
        gestures = {};
        imports = {
          max_width = 1024;
          max_height = 1024;
          limit_texture_size = false;
          lossless_small = true;
          next_modify = false;
          next_copy = false;
          next_transfer = true;
          share_group = false;
          everyone_copy = false;
          permissions_by_type = {
            texture = null;
            sound = null;
            animation = null;
            mesh = null;
            material = null;
          };
          show_payment = true;
          preview_on_avatar = false;
          mesh_auto_weights = true;
          mesh_auto_preview_weights = true;
          mesh_reliable_default = false;
          mesh_model_limit = 768;
          mesh_upload_timeout = 600;
          mesh_suffixes = [
            "LOD0"
            "LOD1"
            "LOD2"
            ""
            "PHYS"
          ];
          mesh_physics_preset = "";
          local_assume_meters = false;
          local_mesh_auto_reload = false;
          local_reload_seconds = 3.0;
          preview_background = null;
          preview_edges = null;
          preview_physics_fill = null;
          preview_physics_edges = null;
          preview_degenerate_fill = null;
          preview_degenerate_edges = null;
        };
        ao = {};
        bridge = {
          a0e0a6e1-0000-0000-0000-000000000001 = {
            enabled = false;
            indicator = false;
            mode = "bridge";
          };
        };
        movements = {
          a0e0a6e1-0000-0000-0000-000000000001 = {
            running = false;
            fly_assist = false;
            swimming = false;
            water_walk = false;
            water_jumps = true;
            pass_wall = false;
            jump_obstacles = true;
            run_multiplier = 1.0;
            swim_speed = 5.0;
            fly_multiplier = 1.0;
            float_height = 0.0;
            style = "Breaststroke";
            discover_strokes = [
              true
              true
              true
            ];
            controller_version = 6;
          };
        };
        snapshot = {
          aspect = "Window";
          resolution = "Uhd";
          custom = [
            1920
            1080
          ];
          keep_ratio = true;
          format = "Png";
          jpeg_quality = 75;
          interface = false;
          huds = false;
          auto_refresh = false;
          base_name = "Snapshot";
          guide = "Thirds";
          sound = true;
          profile_size = "S640";
          profile_location = true;
          postcard_size = "S800";
          dof = {
            enabled = true;
            f_number = 2.8;
            focus = "Click";
            distance = 5.0;
          };
          quality = false;
          viewfinder = {
            display = "Full";
            area = "Avatar";
            peaking = "White";
            beep = true;
            hints = true;
            controls = "Always";
            pad = false;
            timer = 0;
            dof_defaulted = false;
          };
          looks = [];
          look_settings = {};
        };
        dof = {
          enabled = false;
          in_edit = false;
          focus = "Camera";
          f_number = 9.0;
          focal_length = 50.0;
          reference_fov = 60.0;
          max_coc = 10.0;
          transition = 0.5;
          quality = 0.7;
        };
        shape_show_hints = true;
        shape_height_feet = false;
        customize_animation = true;
        script_editor = {
          colors = {};
          font_size = 13.0;
          word_wrap = true;
          search_prefer_left = false;
          search_inline = false;
          convert_tabs = true;
          preprocessor = false;
          optimize = true;
          switches = true;
          lazy_lists = true;
          disk_includes = false;
          owner_say_debug = false;
          recompile = false;
          external_editor = "";
          help_follows_cursor = false;
        };
        grid = "SecondLife";
        grids = [];
        start_location = "last";
        start_region = "";
        draw_distance = 128.0;
        gpu_driver_dismissed = "";
        allow_overlays = false;
        vsync = false;
        shadows = true;
        force_midday = false;
        time_of_day = 0;
        env_manual_transition = 0.0;
        env_persist = true;
        exposure = 1.0;
        sharpen = 0.4;
        glow = true;
        bloom = false;
        bloom_strength = 0.5;
        occlusion_culling = true;
        lod_factor = 2.0;
        texture_budget_auto = false;
        texture_budget_mb = 4096;
        ui_scale = 1.0;
        use_pie_menu = false;
        world_context_menus = {
          profiles = {};
        };
        particle_filters = {
          objects = [];
          owners = [];
        };
        snap_windows = true;
        show_perf = false;
        show_chat = true;
        show_minimap = true;
        standalone_place_details = false;
        inspect_columns = 1023;
        confirm_teleports = true;
        confirm_no_transfer_settings = true;
        confirm_object_bonus = true;
        confirm_return_to_owner = true;
        confirm_attachment_drop = true;
        confirm_script_modify = true;
        confirm_payments = true;
        payment_confirm_threshold = 200;
        always_track_payments = false;
        payment_opens_conversation = true;
        maps = {
          mini_scale = 128.0;
          mini_rotate = false;
          mini_objects = true;
          mini_physical = false;
          mini_scripted = false;
          mini_temp_on_rez = false;
          mini_property_lines = true;
          mini_for_sale = false;
          mini_collision = true;
          mini_auto_center = true;
          mini_double_click = 2;
          world_scale = 128.0;
          world_people = true;
          world_infohubs = true;
          world_telehubs = true;
          world_land_for_sale = true;
          world_events = true;
          world_mature_events = true;
          world_adult_events = false;
          world_grid_coords = false;
          world_double_click_tp = true;
          ban_lines = 1;
        };
        search = {
          group_maturity = 13;
          places = {
            pg = true;
            mature = false;
            adult = false;
          };
          land = {
            pg = true;
            mature = false;
            adult = false;
          };
          events = {
            pg = true;
            mature = false;
            adult = false;
          };
          classifieds = {
            pg = true;
            mature = false;
            adult = false;
          };
          land_limit_price = true;
          land_limit_area = false;
          land_type = 0;
          teleport_action = 1;
          aurora_ratings = {
            pg = true;
            mature = false;
            adult = false;
          };
        };
        show_people = true;
        people_tab = 0;
        show_appearance = false;
        appearance_fill_previews = false;
        show_ao = false;
        loading_backdrop = true;
        mouse_sensitivity = 1.0;
        font = "Inter";
        font_scale = 1.0;
        show_chat_channel = false;
        script_errors_in_chat = true;
        script_errors_to_channel = false;
        script_errors_channel = 1;
        compact_automated_chat = false;
        compact_im_system_lines = false;
        chat_keep_focus = true;
        chat_gesture_autocomplete = true;
        chat_name_prediction = true;
        colon_emote = false;
        chat_mention_autocomplete = true;
        autohide_chat_bar = false;
        show_contacts_tab = true;
        conversations_own_windows = false;
        send_typing_state = true;
        play_typing_anim = true;
        type_during_emote = false;
        typing_in_name_tags = true;
        typing_chevron = false;
        chat_bubbles = false;
        chat_bubbles_hide_console = true;
        typing_bubbles = false;
        chat_bubble_opacity = 0.5;
        flash_unread_conversations = true;
        flash_conversations_button = true;
        flash_conversations_nearby = true;
        chat_thumbnails = "ChatBar";
        chat_thumbnails_flash = true;
        flash_on_message = true;
        flash_on_object_im = true;
        flash_on_script_dialog = false;
        system_notifications = false;
        system_notifications_when_active = false;
        chat_toast_seconds = 20.0;
        presence_position = "TopRight";
        toast_im = true;
        toast_group_im = false;
        ims_in_notification_center = false;
        im_toast_seconds = 30.0;
        log_im = true;
        log_nearby = false;
        reopen_ims = false;
        log_dated_names = false;
        warn_external_links = true;
        trusted_sites = {
          added = [];
          removed = [];
        };
        mute_all_groups = false;
        mute_groups_without_notices = false;
        group_snooze_minutes = 15;
        group_snooze_ask = false;
        report_blocks = false;
        show_joined_group_invitations = false;
        script_count_alert = false;
        script_count_threshold = 100;
        sim_version_alert = true;
        object_im_filter = {
          on = false;
          scope = "Region";
        };
        anti_spam = {
          enabled = false;
          own_objects = false;
          global = false;
          period = 4;
          amount = 10;
          newlines = 70;
          sound_multiplier = 6;
          preload_multiplier = 6;
        };
        rlva_enabled = false;
        rlva = {
          im_queries = true;
          im_queries_auto_share = false;
          allow_shared_offers = true;
          allow_environment_locks = true;
          temporary_controllers = true;
          experience_maturity = 2;
          allow_ooc = true;
          show_ellipsis = true;
          split_redirect_chat = false;
          show_redirect_typing = false;
          replace_unlocked = true;
          experimental_commands = true;
          debug_commands = false;
          debug_hide_unset_duplicate = false;
          compatibility_list = "";
          legacy_naming = true;
          shared_wear = true;
          auto_rename = true;
          hide_locked_attachments = false;
          hide_locked_layers = false;
          wear_add_prefix = "+";
          wear_replace_prefix = "";
        };
        pose_requests = {
          policy = "Friends";
          blocked = [];
        };
        poser = {
          stop_on_close = true;
          markers = true;
          natural = true;
          dof = false;
          sensitivity = 0.5;
          also_bvh = false;
          unlock_pelvis = false;
          confirm_overwrite = false;
          confirm_close = true;
        };
        autoresponse = {
          autorespond = false;
          reject_teleports = false;
          reject_group_invites = false;
          ignore_adhoc = false;
          report_ignored_adhoc = false;
          dnd_text = "This resident has enabled Do Not Disturb and will see your message later.";
          autorespond_text = "The resident you messaged has enabled Aurora Viewer's auto-response mode and does not want to be disturbed. Your message will still appear in their IM window for later reading.";
          send_away = false;
          away_text = "The resident you messaged is away. Your message will appear in their IM window for later reading.";
          send_muted = false;
          muted_text = "The resident you messaged has blocked all messages from you.";
          reject_teleports_text = "The resident you messaged has enabled Aurora Viewer's mode that rejects all teleport offers and requests. They do not want to be disturbed by teleport requests, but you can still send them an IM.";
          away_after_minutes = 0;
          sit_when_away = false;
          quit_after_away_minutes = 0;
        };
        chat_commands = {
          enabled = true;
          calc = "calc";
          draw_distance = "dd";
          bandwidth = "bw";
          copy_cam = "cpcampos";
          paste_cam = "pstcampos";
          ao = "cao";
          clear_chat = "clrchat";
          media = "/media";
          music = "/music";
          rez_platform = "rezplat";
          platform_size = 30.0;
          key_to_name = "key2name";
          roll_dice = "rolld";
          track_pos = "trkpos";
          pos = "gtp";
          ground = "flr";
          height = "gth";
          teleport_to_cam = "tp2cam";
          offer_tp = "offertp";
          tp2 = "tp2";
          teleport_home = "tph";
          map_to = "mapto";
          map_to_keep_pos = false;
          announce_to_channel = false;
          announce_channel = 362395;
        };
        keywords = {
          on = false;
          in_chat = false;
          in_im = false;
          speakers_name = false;
          case_sensitive = false;
          whole_words = false;
          words = "";
          change_color = false;
          color = [
            255
            153
            0
            255
          ];
          play_sound = false;
        };
        spelling = {
          enabled = true;
          main = "en_us";
          extra = [
            "sl"
          ];
        };
        auto_replace = false;
        name_tag_distance = 64.0;
        show_own_name_tag = true;
        show_other_name_tags = true;
        temporary_name_tags = false;
        name_tag_show_seconds = 10.0;
        classic_name_tags = false;
        plates_hover_expand = true;
        plates_jiggle = false;
        plates_click_combo = false;
        plate_click = "Nothing";
        plate_shift_click = "Nothing";
        plate_ctrl_click = "Nothing";
        classic_profiles = false;
        profile_rights = true;
        classic_pay_window = false;
        legacy_money_tracker = false;
        classic_bars = false;
        place_bar_stretch = true;
        place_bar_rights_text = false;
        system_island = {
          clock = true;
          ping = true;
          fps = true;
          media = true;
          clock_zone = "Slt";
          clock_seconds = true;
          clock_format = "Auto";
        };
        confirm_hide_interface = true;
        immersive_name_tags = false;
        immersive_huds = true;
        show_net_stats = false;
        show_balance = true;
        classic_people = false;
        classic_restart_alert = false;
        classic_chat_lines = false;
        classic_rez_effect = false;
        hover_tips = {
          enabled = false;
          form = "Card";
          all_objects = false;
          land = false;
          group_titles = true;
          delay = 0.35;
        };
        classic_hover_tips = false;
        predict_own_motion = false;
        synchronize_animations = false;
        sort_received_items = false;
        received_items_since = 0;
        notify_deliveries = true;
        ground_avatar_feet = false;
        ground_feet_while_moving = false;
        ground_feet_max_height = 0.4;
        ground_feet_max_avatars = 5;
        collisions = {
          in_chat = false;
          report = false;
          channel = -25000;
        };
        reduce_motion = false;
        color_blindness = "Off";
        color_blindness_strength = 1.0;
        high_contrast = false;
        interface_colors = {
          accent = null;
          surface = null;
          text = null;
        };
        classic_controls = false;
        camera_shots = [];
        chat_style = "Aurora";
        link_previews = {
          ims = true;
          groups = true;
          nearby = false;
          blur_groups = true;
          load = "Trusted";
          player = "InCard";
          size = "Medium";
          hidden_sites = [];
          picture_sites = [];
          video_volume = 1.0;
          subtitles = false;
          subtitle_language = "";
        };
        gifs = {
          show_button = false;
          hidden_by_user = false;
          provider = "Giphy";
          rating = "Moderate";
          giphy_key = "";
          klipy_key = "";
          customer_id = "";
        };
        notifications_style = "Aurora";
        world_map_style = "Aurora";
        photo_window = "Aurora";
        classic_about_land = false;
        classic_search = false;
        classic_region_estate = false;
        classic_places = false;
        places_sort = "Visit";
        invert_mouse = false;
        world_mouse_walk = false;
        arrows_strafe = false;
        arrow_keys_always_move = false;
        letter_keys_move = true;
        walk_backwards_without_turning = false;
        automatic_fly = true;
        automatic_land = true;
        fly_after_teleport = false;
        crouch_toggle = false;
        quickjump = false;
        block_click_sit = false;
        double_click = "Nothing";
        follow = {
          distance = 2.0;
          teleport_if_stuck = false;
        };
        lookat = {
          show_targets = false;
          show_names = 1;
          hide_own = true;
          lines = false;
          private = false;
          private_local = false;
          private_point_at = false;
          limit_distance = false;
          max_distance = 1.0;
          head_yaw = 90.0;
          head_pitch = 90.0;
          static_eyes = false;
          style = "Aurora";
          aim = "Point";
        };
        shadow_quality = 2;
        projector_shadows = false;
        contact_shadows = true;
        antialiasing = 6;
        render_scale_percent = 67;
        specular_aa = true;
        tonemapper = 1;
        tonemap_mix = 0.7;
        hdr_emissive = true;
        fps_cap = true;
        fps_limit = 500;
        background_fps_cap = true;
        background_fps_limit = 15;
        max_particles = 4096;
        max_avatars = 11;
        ssao = 1;
        ao_method = 1;
        gtao_quality = 2;
        water_effects = {
          enabled = false;
          quality = 1;
          waves = true;
          absorption = true;
          fresnel = true;
          wet_ground = true;
          shore_foam = true;
          contact_foam = true;
          crest_foam = true;
          interactions = true;
          caustics = true;
          splashes = true;
          bubbles = true;
        };
        screen_indirect_light = false;
        screen_indirect_intensity = 1.5;
        water_reflections = 1;
        mirrors = 0;
        reflection_probes = 2;
        probe_count = 32;
        max_complexity = 300000;
        max_attachment_area = 1000.0;
        loading_avatars = 0;
        complexity_mode = 0;
        avatar_physics = true;
        avatar_physics_detail = 1.0;
        render_exceptions = [];
        tag_complexity = true;
        tag_complexity_too_complex_only = true;
        tag_complexity_own = false;
        use_display_names = true;
        group_titles = "All";
        trim_resident = true;
        display_name_notices = true;
        ssr = false;
        anisotropy = 8;
        chat_log_location = "";
        bandwidth_kbps = 4000;
        no_neighbour_regions = false;
        parcel_visibility = {
          mode = "Off";
          same_owner = false;
          same_group = false;
          parcels = [];
          always_visible = [];
        };
        chat_bar_width = 0.0;
        chat_island_width = 0.0;
        toolbar_common = {
          buttons = null;
          locked = false;
          bottom_style = {
            mode = null;
            align = null;
            sizing = null;
          };
          left_style = {
            mode = null;
            align = null;
            sizing = null;
          };
          right_style = {
            mode = null;
            align = null;
            sizing = null;
          };
        };
        audio = {
          explorer = {
            avatars = false;
            objects = true;
            collisions = false;
            repeats = false;
          };
          voice_ear = "Camera";
          voice_automatic_gain = true;
          voice_echo_cancellation = true;
          voice_noise_suppression = 4;
          lip_sync = true;
          voice_visualizer = true;
          voice_visualizer_self = true;
          voice_visualizer_dot = true;
          voice_visualizers_in_calls = true;
          conversation_voice_indicator = true;
          volume = [
            0.8
            0.5
            0.5
            0.5
            0.4
            0.5
            0.7
          ];
          perceptual_volume = false;
          muted = [
            false
            false
            false
            false
            false
            false
            false
          ];
          enabled = [
            true
            true
            true
            true
            true
            true
            true
          ];
          music_autoplay = false;
          media_autoplay = false;
          stream_title = "Chat";
          stream_title_announce = false;
          stream_title_channel = 362394;
          stream_title_window = false;
          stream_title_text_only = false;
          mute_when_minimized = false;
          output_device = "";
          input_device = "";
          voice_enabled = true;
          mic_hold = false;
          mic_gain = 1.0;
          collision_sounds = true;
          gesture_sounds = true;
          ui_sounds = true;
          ui = {
            play = {};
            im_mode = "NewSession";
            group_mode = "NewSession";
            conf_mode = "NewSession";
            money_threshold = 50.0;
          };
          saved_streams = [];
          reject_group_calls = false;
          reject_adhoc_calls = false;
          reject_p2p_calls = false;
        };
        media = {
          enabled = true;
          prim_media = true;
          show_on_others = false;
          max_instances = 8;
          allow_scripted = false;
          autoplay_huds = true;
          filter = true;
          filter_trust_own_worn = true;
          filter_explained = false;
          plugin_dir = "";
        };
        colors = {
          relation_names = true;
          tag_me = [
            255
            255
            255
            255
          ];
          tag_muted = [
            111
            123
            160
            255
          ];
          tag_linden = [
            244
            114
            182
            255
          ];
          tag_match = [
            232
            237
            251
            255
          ];
          tag_mismatch = [
            232
            237
            251
            255
          ];
          map_me = [
            139
            92
            246
            255
          ];
          map_other = [
            74
            222
            128
            255
          ];
          map_linden = [
            244
            114
            182
            255
          ];
          map_muted = [
            111
            123
            160
            255
          ];
          map_ranges = true;
          map_whisper_on = true;
          map_say_on = true;
          map_shout_on = true;
          map_whisper = [
            108
            194
            74
            255
          ];
          map_say = [
            108
            194
            74
            255
          ];
          map_shout = [
            224
            102
            26
            255
          ];
          chat_mine = [
            154
            166
            198
            255
          ];
          chat_others = [
            232
            237
            251
            255
          ];
          chat_objects = [
            74
            222
            128
            255
          ];
          chat_linden = [
            244
            114
            182
            255
          ];
          chat_muted = [
            111
            123
            160
            255
          ];
          chat_system = [
            154
            166
            198
            255
          ];
          chat_errors = [
            248
            113
            113
            255
          ];
          chat_object_im = [
            167
            139
            250
            255
          ];
          chat_owner = [
            252
            211
            77
            255
          ];
          chat_urls = [
            94
            234
            212
            255
          ];
          chat_slurl = [
            94
            234
            212
            255
          ];
          chat_direct = [
            251
            146
            60
            255
          ];
          sender_avatar = [
            196
            181
            253
            255
          ];
          sender_object = [
            74
            222
            128
            255
          ];
          mention_text = [
            252
            211
            77
            255
          ];
          mention_residents = [
            139
            92
            246
            255
          ];
          mention_me = [
            79
            70
            229
            255
          ];
        };
        keybinds = {
          map = [
            [
              "Forward"
              [
                {
                  input = {
                    Key = "ArrowUp";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "KeyW";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "Back"
              [
                {
                  input = {
                    Key = "ArrowDown";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "KeyS";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "Left"
              [
                {
                  input = {
                    Key = "ArrowLeft";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "KeyA";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "Right"
              [
                {
                  input = {
                    Key = "ArrowRight";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "KeyD";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "StrafeLeft"
              [
                null
                null
              ]
            ]
            [
              "StrafeRight"
              [
                null
                null
              ]
            ]
            [
              "Up"
              [
                {
                  input = {
                    Key = "PageUp";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "KeyE";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "Down"
              [
                {
                  input = {
                    Key = "PageDown";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "KeyC";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "Fly"
              [
                {
                  input = {
                    Key = "Home";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "KeyF";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "AlwaysRun"
              [
                {
                  input = {
                    Key = "KeyR";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "MoveLock"
              [
                {
                  input = {
                    Key = "KeyP";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "MovementEnhancer"
              [
                {
                  input = {
                    Key = "KeyM";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "PassWall"
              [
                null
                null
              ]
            ]
            [
              "SitGround"
              [
                {
                  input = {
                    Key = "KeyS";
                  };
                  ctrl = false;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "Mouselook"
              [
                {
                  input = {
                    Key = "KeyM";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "ResetCamera"
              [
                {
                  input = {
                    Key = "Escape";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Flycam"
              [
                {
                  input = {
                    Key = "KeyF";
                  };
                  ctrl = false;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CameraControls"
              [
                {
                  input = {
                    Key = "KeyC";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "LensZoomIn"
              [
                {
                  input = {
                    Key = "Digit0";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "Numpad0";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "LensZoomOut"
              [
                {
                  input = {
                    Key = "Digit8";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "Numpad8";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "LensZoomDefault"
              [
                {
                  input = {
                    Key = "Digit9";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "Numpad9";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "CamOrbitCw"
              [
                {
                  input = {
                    Key = "ArrowLeft";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamOrbitCcw"
              [
                {
                  input = {
                    Key = "ArrowRight";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamOrbitOver"
              [
                {
                  input = {
                    Key = "PageUp";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                {
                  input = {
                    Key = "ArrowUp";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
              ]
            ]
            [
              "CamOrbitUnder"
              [
                {
                  input = {
                    Key = "PageDown";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                {
                  input = {
                    Key = "ArrowDown";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
              ]
            ]
            [
              "CamZoomIn"
              [
                {
                  input = {
                    Key = "ArrowUp";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamZoomOut"
              [
                {
                  input = {
                    Key = "ArrowDown";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamPanLeft"
              [
                {
                  input = {
                    Key = "ArrowLeft";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamPanRight"
              [
                {
                  input = {
                    Key = "ArrowRight";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamPanUp"
              [
                {
                  input = {
                    Key = "ArrowUp";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "CamPanDown"
              [
                {
                  input = {
                    Key = "ArrowDown";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "Chat"
              [
                {
                  input = {
                    Key = "Enter";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                {
                  input = {
                    Key = "NumpadEnter";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
              ]
            ]
            [
              "PushToTalk"
              [
                {
                  input = {
                    Mouse = "Middle";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "ToggleMic"
              [
                null
                null
              ]
            ]
            [
              "Conversations"
              [
                {
                  input = {
                    Key = "KeyT";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "People"
              [
                {
                  input = {
                    Key = "KeyA";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Inventory"
              [
                {
                  input = {
                    Key = "KeyI";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "TextureLibrary"
              [
                {
                  input = {
                    Key = "Space";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "IkEdit"
              [
                {
                  input = {
                    Key = "KeyK";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Gestures"
              [
                {
                  input = {
                    Key = "KeyG";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Minimap"
              [
                {
                  input = {
                    Key = "KeyM";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "WorldMap"
              [
                {
                  input = {
                    Key = "KeyM";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "TeleportHistory"
              [
                {
                  input = {
                    Key = "KeyH";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "RegionEstate"
              [
                {
                  input = {
                    Key = "KeyR";
                  };
                  ctrl = false;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "Search"
              [
                {
                  input = {
                    Key = "KeyF";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Performance"
              [
                {
                  input = {
                    Key = "Digit1";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Preferences"
              [
                {
                  input = {
                    Key = "KeyP";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "ToggleInterface"
              [
                {
                  input = {
                    Key = "KeyU";
                  };
                  ctrl = false;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "HoverTips"
              [
                {
                  input = {
                    Key = "KeyT";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Import"
              [
                {
                  input = {
                    Key = "KeyU";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "Beacons"
              [
                {
                  input = {
                    Key = "KeyN";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "PropertyLines"
              [
                {
                  input = {
                    Key = "KeyP";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "LandOwners"
              [
                {
                  input = {
                    Key = "KeyO";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "HideParticles"
              [
                {
                  input = {
                    Key = "Equal";
                  };
                  ctrl = true;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "ShowHuds"
              [
                {
                  input = {
                    Key = "KeyH";
                  };
                  ctrl = false;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "HudDrag"
              [
                {
                  input = {
                    Key = "ControlLeft";
                  };
                  ctrl = false;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "ShowTransparency"
              [
                {
                  input = {
                    Key = "KeyT";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "Rebake"
              [
                {
                  input = {
                    Key = "KeyR";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "DevToolbox"
              [
                {
                  input = {
                    Key = "KeyD";
                  };
                  ctrl = true;
                  shift = false;
                  alt = true;
                }
                null
              ]
            ]
            [
              "StopAnimations"
              [
                {
                  input = {
                    Key = "KeyA";
                  };
                  ctrl = false;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "ResyncAnimations"
              [
                {
                  input = {
                    Key = "KeyS";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "RefreshAttachments"
              [
                {
                  input = {
                    Key = "KeyR";
                  };
                  ctrl = false;
                  shift = true;
                  alt = true;
                }
                null
              ]
            ]
            [
              "PhotoWindow"
              [
                {
                  input = {
                    Key = "KeyS";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "PhotoToDisk"
              [
                {
                  input = {
                    Key = "Backquote";
                  };
                  ctrl = true;
                  shift = false;
                  alt = false;
                }
                null
              ]
            ]
            [
              "EnvSunrise"
              [
                {
                  input = {
                    Key = "KeyU";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "EnvMidday"
              [
                {
                  input = {
                    Key = "KeyY";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "EnvSunset"
              [
                {
                  input = {
                    Key = "KeyN";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "EnvMidnight"
              [
                {
                  input = {
                    Key = "KeyX";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
            [
              "EnvShared"
              [
                {
                  input = {
                    Key = "KeyJ";
                  };
                  ctrl = true;
                  shift = true;
                  alt = false;
                }
                null
              ]
            ]
          ];
        };
        settings_version = 28;
      };
    };
  };
}
