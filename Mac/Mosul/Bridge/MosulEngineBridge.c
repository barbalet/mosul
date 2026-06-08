#include "MosulEngineBridge.h"

#include "mk_ai.h"
#include "mk_asset_manifest.h"
#include "mk_board_view.h"
#include "mk_core.h"
#include "mk_mosul_demo.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MOSUL_BRIDGE_AI_BATTLE_SEED_STEP UINT64_C(0x9E3779B97F4A7C15)

struct MosulEngine {
    char project_root[MOSUL_BRIDGE_PATH_CAPACITY];
    char scenario_path[MOSUL_BRIDGE_PATH_CAPACITY];
    char map_manifest_path[MOSUL_BRIDGE_PATH_CAPACITY];
    char marker_manifest_path[MOSUL_BRIDGE_PATH_CAPACITY];
    char map_overview_path[MOSUL_BRIDGE_PATH_CAPACITY];
    char last_error[MOSUL_BRIDGE_TEXT_CAPACITY];
    mk_scenario_definition_t scenario;
    mk_game_t game;
    mk_asset_map_manifest_t map_manifest;
    mk_asset_marker_manifest_t marker_manifest;
    bool map_manifest_loaded;
    bool marker_manifest_loaded;
};

static void mosul_bridge_copy_text(char *destination, size_t capacity, const char *source) {
    const char *text = source == NULL ? "" : source;
    size_t index = 0;

    if (destination == NULL || capacity == 0) {
        return;
    }

    while (index + 1 < capacity && text[index] != '\0') {
        destination[index] = text[index];
        index += 1;
    }
    destination[index] = '\0';
}

static bool mosul_bridge_join_path(char *destination, size_t capacity, const char *root, const char *relative_path) {
    int written;

    if (destination == NULL || capacity == 0 || root == NULL || relative_path == NULL) {
        return false;
    }

    written = snprintf(destination, capacity, "%s/%s", root, relative_path);
    return written > 0 && (size_t)written < capacity;
}

static bool mosul_bridge_file_exists(const char *path) {
    FILE *file;

    if (path == NULL || path[0] == '\0') {
        return false;
    }

    file = fopen(path, "rb");
    if (file == NULL) {
        return false;
    }

    fclose(file);
    return true;
}

static void mosul_bridge_set_error(MosulEngine *engine, const char *message) {
    if (engine != NULL) {
        mosul_bridge_copy_text(engine->last_error, sizeof(engine->last_error), message);
    }
}

static bool mosul_bridge_load_map_manifest(MosulEngine *engine) {
    mk_result_t result;

    if (engine == NULL) {
        return false;
    }

    if (!mosul_bridge_join_path(
            engine->map_manifest_path,
            sizeof(engine->map_manifest_path),
            engine->project_root,
            "assets/mosul/manifests/market_commercial_streets_2003.mapmanifest")) {
        mosul_bridge_set_error(engine, "Could not build map manifest path.");
        return false;
    }

    result = mk_asset_load_map_manifest(engine->map_manifest_path, engine->project_root, &engine->map_manifest);
    if (result != MK_OK) {
        mosul_bridge_set_error(engine, "Could not load Market / Commercial Streets map manifest.");
        return false;
    }

    engine->map_manifest_loaded = true;
    if (!mosul_bridge_join_path(
            engine->map_overview_path,
            sizeof(engine->map_overview_path),
            engine->project_root,
            engine->map_manifest.runtime_overview_path)) {
        mosul_bridge_set_error(engine, "Could not build runtime map overview path.");
        return false;
    }

    if (!mosul_bridge_file_exists(engine->map_overview_path)
        && !mosul_bridge_join_path(
            engine->map_overview_path,
            sizeof(engine->map_overview_path),
            engine->project_root,
            engine->map_manifest.overview_path)) {
        mosul_bridge_set_error(engine, "Could not build source map overview path.");
        return false;
    }

    return true;
}

static bool mosul_bridge_load_marker_manifest(MosulEngine *engine) {
    mk_result_t result;

    if (engine == NULL) {
        return false;
    }

    if (!mosul_bridge_join_path(
            engine->marker_manifest_path,
            sizeof(engine->marker_manifest_path),
            engine->project_root,
            "assets/mosul/manifests/mosul_2003_markers.markermanifest")) {
        mosul_bridge_set_error(engine, "Could not build marker manifest path.");
        return false;
    }

    result = mk_asset_load_marker_manifest(engine->marker_manifest_path, &engine->marker_manifest);
    if (result != MK_OK) {
        mosul_bridge_set_error(engine, "Could not load MOSUL 2003 tactical marker manifest.");
        return false;
    }

    engine->marker_manifest_loaded = true;
    return true;
}

static bool mosul_bridge_load_game(MosulEngine *engine, uint32_t battle_index) {
    mk_result_t result;
    uint32_t normalized_battle_index;

    if (engine == NULL) {
        return false;
    }

    normalized_battle_index = battle_index == 0U ? 1U : battle_index;

    if (!mosul_bridge_join_path(
            engine->scenario_path,
            sizeof(engine->scenario_path),
            engine->project_root,
            MK_MOSUL_DEFAULT_SCENARIO_PATH)) {
        mosul_bridge_set_error(engine, "Could not build scenario path.");
        return false;
    }

    result = mk_mosul_load_scenario_file(engine->scenario_path, engine->project_root, &engine->scenario);
    if (result != MK_OK) {
        mosul_bridge_set_error(engine, "Could not load 2003 Market / Commercial Streets scenario data.");
        return false;
    }

    engine->scenario.seed += (uint64_t)(normalized_battle_index - 1U) * MOSUL_BRIDGE_AI_BATTLE_SEED_STEP;

    result = mk_game_load_scenario(&engine->game, &engine->scenario);
    if (result != MK_OK) {
        mosul_bridge_set_error(engine, "Could not load scenario into the modernerKrieg core.");
        return false;
    }

    mosul_bridge_set_error(engine, "");
    return true;
}

MosulEngine *MosulEngineCreate(const char *moderner_krieg_root) {
    MosulEngine *engine;

    if (moderner_krieg_root == NULL || moderner_krieg_root[0] == '\0') {
        return NULL;
    }

    engine = (MosulEngine *)calloc(1, sizeof(*engine));
    if (engine == NULL) {
        return NULL;
    }

    mosul_bridge_copy_text(engine->project_root, sizeof(engine->project_root), moderner_krieg_root);

    if (!mosul_bridge_load_map_manifest(engine)
        || !mosul_bridge_load_marker_manifest(engine)
        || !mosul_bridge_load_game(engine, 1U)) {
        return engine;
    }

    return engine;
}

void MosulEngineDestroy(MosulEngine *engine) {
    free(engine);
}

bool MosulEngineReset(MosulEngine *engine) {
    return MosulEngineResetBattle(engine, 1U);
}

bool MosulEngineResetBattle(MosulEngine *engine, uint32_t battle_index) {
    return mosul_bridge_load_game(engine, battle_index);
}

bool MosulEngineStep(MosulEngine *engine, uint32_t steps) {
    uint32_t index;

    if (engine == NULL) {
        return false;
    }

    for (index = 0; index < steps; ++index) {
        mk_game_step(&engine->game);
    }

    return true;
}

bool MosulEngineRunAI(MosulEngine *engine, uint32_t steps) {
    uint32_t index;

    if (engine == NULL) {
        return false;
    }

    for (index = 0; index < steps; ++index) {
        if (mk_ai_issue_basic_orders(&engine->game) != MK_OK) {
            mosul_bridge_set_error(engine, "AI order generation failed.");
            return false;
        }
        mk_game_step(&engine->game);
    }

    return true;
}

const char *MosulEngineScenarioName(const MosulEngine *engine) {
    return engine == NULL ? "" : engine->game.scenario_name;
}

const char *MosulEngineBriefing(const MosulEngine *engine) {
    return engine == NULL ? "" : engine->game.briefing;
}

const char *MosulEngineMapName(const MosulEngine *engine) {
    return engine == NULL ? "" : engine->game.map.name;
}

const char *MosulEngineMapOverviewPath(const MosulEngine *engine) {
    return engine == NULL ? "" : engine->map_overview_path;
}

const char *MosulEngineLastError(const MosulEngine *engine) {
    return engine == NULL ? "Engine is not available." : engine->last_error;
}

uint32_t MosulEngineTick(const MosulEngine *engine) {
    return engine == NULL ? 0U : engine->game.tick;
}

float MosulEngineMapWidthM(const MosulEngine *engine) {
    return engine == NULL ? 0.0f : engine->game.map.width_m;
}

float MosulEngineMapHeightM(const MosulEngine *engine) {
    return engine == NULL ? 0.0f : engine->game.map.height_m;
}

uint32_t MosulEngineSelectedUnitID(const MosulEngine *engine) {
    return engine == NULL ? 0U : engine->game.selected_unit_id;
}

bool MosulEngineSelectUnit(MosulEngine *engine, uint32_t unit_id) {
    return engine != NULL && mk_game_select_unit(&engine->game, unit_id) == MK_OK;
}

bool MosulEngineSelectUnitAt(MosulEngine *engine, float x_m, float y_m) {
    uint32_t selected_unit_id = 0;
    mk_vec2_t position;

    if (engine == NULL) {
        return false;
    }

    position.x = x_m;
    position.y = y_m;
    if (mk_game_select_unit_at(&engine->game, position, MK_UNIT_PICK_RADIUS_M, &selected_unit_id) != MK_OK) {
        mk_game_clear_selection(&engine->game);
        return false;
    }

    return true;
}

bool MosulEngineClearSelection(MosulEngine *engine) {
    return engine != NULL && mk_game_clear_selection(&engine->game) == MK_OK;
}

bool MosulEngineIssueSelectedOrder(MosulEngine *engine, int order) {
    if (engine == NULL || engine->game.selected_unit_id == 0U) {
        return false;
    }

    return mk_game_issue_order(&engine->game, engine->game.selected_unit_id, (mk_order_t)order) == MK_OK;
}

bool MosulEngineIssueSelectedMove(MosulEngine *engine, float x_m, float y_m) {
    mk_vec2_t position;

    if (engine == NULL) {
        return false;
    }

    position.x = x_m;
    position.y = y_m;
    return mk_game_issue_selected_move_order(&engine->game, position) == MK_OK;
}

bool MosulEngineIssueSelectedInvestigate(MosulEngine *engine, float x_m, float y_m) {
    mk_vec2_t position;

    if (engine == NULL) {
        return false;
    }

    position.x = x_m;
    position.y = y_m;
    return mk_game_issue_selected_investigate_order(&engine->game, position) == MK_OK;
}

static size_t mosul_bridge_unit_casualties(const mk_unit_t *unit) {
    size_t index;
    size_t count = 0;

    if (unit == NULL) {
        return 0;
    }

    for (index = 0; index < unit->soldier_count; ++index) {
        if (unit->soldiers[index].casualty) {
            count += 1;
        }
    }

    return count;
}

static const mk_soldier_t *mosul_bridge_representative_soldier(const mk_unit_t *unit) {
    size_t index;
    const mk_soldier_t *fallback = NULL;

    if (unit == NULL) {
        return NULL;
    }

    for (index = 0; index < unit->soldier_count; ++index) {
        const mk_soldier_t *soldier = &unit->soldiers[index];

        if (fallback == NULL) {
            fallback = soldier;
        }
        if (!soldier->casualty) {
            return soldier;
        }
    }

    return fallback;
}

static const char *mosul_bridge_unit_sprite_id(const mk_unit_t *unit) {
    const mk_soldier_t *soldier = mosul_bridge_representative_soldier(unit);

    if (unit == NULL) {
        return "";
    }

    switch (unit->side) {
    case MK_SIDE_PLAYER:
        if (soldier != NULL) {
            switch (soldier->role) {
            case MK_ROLE_LEADER:
                return "us_army_squad_leader";
            case MK_ROLE_MACHINE_GUNNER:
                return "us_army_automatic_rifleman";
            case MK_ROLE_MARKSMAN:
                return "us_army_marksman";
            case MK_ROLE_ENGINEER:
                return "us_army_engineer_breacher";
            case MK_ROLE_MEDIC:
                return "us_army_medic";
            default:
                break;
            }
        }
        return "us_army_rifleman";
    case MK_SIDE_OPFOR:
        if (soldier != NULL) {
            switch (soldier->role) {
            case MK_ROLE_RPG:
                return "rpg_gunner";
            case MK_ROLE_MACHINE_GUNNER:
                return "machine_gunner";
            case MK_ROLE_MARKSMAN:
                return "sniper_marksman";
            default:
                break;
            }
        }
        if (strcmp(unit->template_id, "rooftop_watcher") == 0) {
            return "sniper_marksman";
        }
        if (strcmp(unit->template_id, "market_looter") == 0) {
            return "armed_looter";
        }
        return "insurgent_cell_rifleman";
    case MK_SIDE_CIVILIAN:
        return "adult_woman";
    default:
        return "us_army_rifleman";
    }
}

static const char *mosul_bridge_civilian_sprite_id(const mk_civilian_t *civilian) {
    if (civilian == NULL) {
        return "";
    }
    if (strstr(civilian->name, "Child") != NULL) {
        return "young_boy";
    }
    if (strstr(civilian->name, "Elder") != NULL) {
        return "old_man";
    }
    return "adult_woman";
}

static const char *mosul_bridge_order_marker_id(mk_order_t order) {
    switch (order) {
    case MK_ORDER_HOLD:
        return "order_hold";
    case MK_ORDER_MOVE:
    case MK_ORDER_ASSAULT_MOVE:
        return "move_target";
    case MK_ORDER_FIRE:
        return "fire_order";
    case MK_ORDER_SUPPRESS:
        return "order_suppress";
    case MK_ORDER_OVERWATCH:
        return "order_overwatch";
    case MK_ORDER_BREACH:
        return "order_breach_search";
    case MK_ORDER_WITHDRAW:
        return "order_withdraw";
    case MK_ORDER_INVESTIGATE:
        return "order_investigate";
    case MK_ORDER_RALLY:
        return "order_hold";
    default:
        return "";
    }
}

static const char *mosul_bridge_target_marker_id(const mk_unit_t *unit) {
    if (unit == NULL || !unit->has_move_target) {
        return "";
    }
    if (unit->order == MK_ORDER_INVESTIGATE
        || unit->order == MK_ORDER_BREACH
        || unit->order == MK_ORDER_WITHDRAW
        || unit->order == MK_ORDER_SUPPRESS) {
        return mosul_bridge_order_marker_id(unit->order);
    }
    return "move_target";
}

static const char *mosul_bridge_civilian_marker_id(const mk_civilian_t *civilian) {
    if (civilian == NULL) {
        return "";
    }
    if (civilian->state == MK_CIVILIAN_WOUNDED || civilian->state == MK_CIVILIAN_DEAD) {
        return "casualty";
    }
    return civilian->risk > 0 ? "civilian_risk" : "";
}

static const char *mosul_bridge_contact_marker_id(const mk_contact_report_t *contact) {
    if (contact == NULL) {
        return "";
    }
    switch (contact->kind) {
    case MK_CONTACT_REPORT_FIRE:
        return contact->visible ? "fire_order" : "hidden_contact";
    case MK_CONTACT_REPORT_CIVILIAN_RISK:
        return "civilian_risk";
    case MK_CONTACT_REPORT_SEARCH:
    case MK_CONTACT_REPORT_BREACH:
        return "breach_search";
    case MK_CONTACT_REPORT_SUSPECTED_DANGER:
    case MK_CONTACT_REPORT_FALSE_CONTACT:
    case MK_CONTACT_REPORT_REVEAL:
        return "hidden_contact";
    default:
        return contact->visible ? "" : "hidden_contact";
    }
}

static void mosul_bridge_copy_marker_id(
    const MosulEngine *engine,
    char *destination,
    size_t capacity,
    const char *marker_id
) {
    if (marker_id == NULL
        || marker_id[0] == '\0'
        || engine == NULL
        || !engine->marker_manifest_loaded
        || mk_asset_find_marker(&engine->marker_manifest, marker_id) == NULL) {
        mosul_bridge_copy_text(destination, capacity, "");
        return;
    }

    mosul_bridge_copy_text(destination, capacity, marker_id);
}

size_t MosulEngineCopyUnits(const MosulEngine *engine, MosulUnitSummary *out_units, size_t capacity) {
    size_t index;
    size_t count;

    if (engine == NULL || out_units == NULL || capacity == 0) {
        return 0;
    }

    count = engine->game.unit_count < capacity ? engine->game.unit_count : capacity;
    for (index = 0; index < count; ++index) {
        const mk_unit_t *unit = &engine->game.units[index];
        MosulUnitSummary *summary = &out_units[index];

        memset(summary, 0, sizeof(*summary));
        summary->id = unit->id;
        mosul_bridge_copy_text(summary->name, sizeof(summary->name), unit->name);
        mosul_bridge_copy_text(summary->sprite_id, sizeof(summary->sprite_id), mosul_bridge_unit_sprite_id(unit));
        mosul_bridge_copy_marker_id(
            engine,
            summary->selection_marker_id,
            sizeof(summary->selection_marker_id),
            unit->id == engine->game.selected_unit_id ? "selection_ring" : ""
        );
        mosul_bridge_copy_marker_id(
            engine,
            summary->order_marker_id,
            sizeof(summary->order_marker_id),
            mosul_bridge_order_marker_id(unit->order)
        );
        mosul_bridge_copy_marker_id(
            engine,
            summary->route_marker_id,
            sizeof(summary->route_marker_id),
            unit->has_move_target ? "move_route" : ""
        );
        mosul_bridge_copy_marker_id(
            engine,
            summary->target_marker_id,
            sizeof(summary->target_marker_id),
            mosul_bridge_target_marker_id(unit)
        );
        mosul_bridge_copy_marker_id(
            engine,
            summary->suppression_marker_id,
            sizeof(summary->suppression_marker_id),
            unit->suppression > 0 ? "suppression" : ""
        );
        mosul_bridge_copy_marker_id(
            engine,
            summary->casualty_marker_id,
            sizeof(summary->casualty_marker_id),
            mosul_bridge_unit_casualties(unit) > 0 ? "casualty" : ""
        );
        summary->side = (int)unit->side;
        summary->order = (int)unit->order;
        summary->status = (int)unit->status;
        summary->x_m = unit->position_m.x;
        summary->y_m = unit->position_m.y;
        summary->target_x_m = unit->target_position_m.x;
        summary->target_y_m = unit->target_position_m.y;
        summary->has_target = unit->has_move_target;
        summary->hidden = unit->hidden;
        summary->revealed = unit->revealed;
        summary->selected = unit->id == engine->game.selected_unit_id;
        summary->suppression = unit->suppression;
        summary->morale = unit->morale;
        summary->soldier_count = unit->soldier_count;
        summary->casualty_count = mosul_bridge_unit_casualties(unit);
    }

    return count;
}

size_t MosulEngineCopyObjectives(const MosulEngine *engine, MosulObjectiveSummary *out_objectives, size_t capacity) {
    size_t index;
    size_t count;

    if (engine == NULL || out_objectives == NULL || capacity == 0) {
        return 0;
    }

    count = engine->game.objective_count < capacity ? engine->game.objective_count : capacity;
    for (index = 0; index < count; ++index) {
        const mk_objective_t *objective = &engine->game.objectives[index];
        MosulObjectiveSummary *summary = &out_objectives[index];

        memset(summary, 0, sizeof(*summary));
        summary->id = objective->id;
        mosul_bridge_copy_text(summary->name, sizeof(summary->name), objective->name);
        mosul_bridge_copy_text(summary->label, sizeof(summary->label), objective->label);
        mosul_bridge_copy_marker_id(engine, summary->marker_id, sizeof(summary->marker_id), "objective");
        summary->kind = (int)objective->kind;
        summary->controlling_side = (int)objective->controlling_side;
        summary->x_m = objective->position_m.x;
        summary->y_m = objective->position_m.y;
        summary->radius_m = objective->radius_m;
        summary->value = objective->value;
    }

    return count;
}

size_t MosulEngineCopyCivilians(const MosulEngine *engine, MosulCivilianSummary *out_civilians, size_t capacity) {
    size_t index;
    size_t count;

    if (engine == NULL || out_civilians == NULL || capacity == 0) {
        return 0;
    }

    count = engine->game.civilian_count < capacity ? engine->game.civilian_count : capacity;
    for (index = 0; index < count; ++index) {
        const mk_civilian_t *civilian = &engine->game.civilians[index];
        MosulCivilianSummary *summary = &out_civilians[index];

        memset(summary, 0, sizeof(*summary));
        summary->id = civilian->id;
        mosul_bridge_copy_text(summary->name, sizeof(summary->name), civilian->name);
        mosul_bridge_copy_text(summary->sprite_id, sizeof(summary->sprite_id), mosul_bridge_civilian_sprite_id(civilian));
        mosul_bridge_copy_marker_id(
            engine,
            summary->marker_id,
            sizeof(summary->marker_id),
            mosul_bridge_civilian_marker_id(civilian)
        );
        summary->x_m = civilian->position_m.x;
        summary->y_m = civilian->position_m.y;
        summary->state = (int)civilian->state;
        summary->stress = civilian->stress;
        summary->risk = civilian->risk;
        summary->protected_noncombatant = civilian->protected_noncombatant;
    }

    return count;
}

size_t MosulEngineCopyContacts(const MosulEngine *engine, MosulContactSummary *out_contacts, size_t capacity) {
    size_t index;
    size_t count;

    if (engine == NULL || out_contacts == NULL || capacity == 0) {
        return 0;
    }

    count = engine->game.contact_report_count < capacity ? engine->game.contact_report_count : capacity;
    for (index = 0; index < count; ++index) {
        const mk_contact_report_t *contact = &engine->game.contact_reports[index];
        MosulContactSummary *summary = &out_contacts[index];

        memset(summary, 0, sizeof(*summary));
        summary->id = contact->id;
        summary->tick = contact->tick;
        mosul_bridge_copy_marker_id(
            engine,
            summary->marker_id,
            sizeof(summary->marker_id),
            mosul_bridge_contact_marker_id(contact)
        );
        summary->kind = (int)contact->kind;
        summary->side = (int)contact->side;
        summary->x_m = contact->position_m.x;
        summary->y_m = contact->position_m.y;
        summary->target_x_m = contact->target_position_m.x;
        summary->target_y_m = contact->target_position_m.y;
        summary->intensity = contact->shots_fired + contact->hits + contact->suppression_added + contact->civilian_risk_added;
        summary->confidence = contact->confidence;
        summary->visible = contact->visible;
        summary->resolved = contact->resolved;
    }

    return count;
}

static void mosul_bridge_copy_score_summary(MosulScoreSummary *out_score, const mk_score_t *score) {
    memset(out_score, 0, sizeof(*out_score));
    out_score->objective_points = score->objective_points;
    out_score->interaction_points = score->interaction_points;
    out_score->civilian_risk_penalty = score->civilian_risk_penalty;
    out_score->casualty_penalty = score->casualty_penalty;
    out_score->time_penalty = score->time_penalty;
    out_score->total_score = score->total_score;
    out_score->player_casualties = score->player_casualties;
    out_score->opfor_casualties = score->opfor_casualties;
    out_score->civilian_casualties = score->civilian_casualties;
    out_score->civilian_risk = score->civilian_risk;
    out_score->controlled_objectives = score->controlled_objectives;
    out_score->contested_objectives = score->contested_objectives;
    out_score->outcome = (int)score->outcome;
}

bool MosulEngineCopyScore(const MosulEngine *engine, MosulScoreSummary *out_score) {
    mk_score_t score;

    if (engine == NULL || out_score == NULL || mk_game_score(&engine->game, &score) != MK_OK) {
        return false;
    }

    mosul_bridge_copy_score_summary(out_score, &score);
    return true;
}

bool MosulEngineCopyAfterAction(const MosulEngine *engine, MosulAfterActionSummary *out_report) {
    mk_after_action_report_t report;

    if (engine == NULL
        || out_report == NULL
        || mk_game_after_action_report(&engine->game, &report) != MK_OK) {
        return false;
    }

    memset(out_report, 0, sizeof(*out_report));
    mosul_bridge_copy_score_summary(&out_report->score, &report.score);
    mosul_bridge_copy_text(out_report->summary, sizeof(out_report->summary), report.summary);
    mosul_bridge_copy_text(out_report->narrative, sizeof(out_report->narrative), report.narrative);
    return true;
}
