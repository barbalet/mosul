#ifndef MOSUL_ENGINE_BRIDGE_H
#define MOSUL_ENGINE_BRIDGE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define MOSUL_BRIDGE_NAME_CAPACITY 64
#define MOSUL_BRIDGE_TEXT_CAPACITY 256
#define MOSUL_BRIDGE_PATH_CAPACITY 1024
#define MOSUL_BRIDGE_MAX_UNITS 64
#define MOSUL_BRIDGE_MAX_OBJECTIVES 16
#define MOSUL_BRIDGE_MAX_CIVILIANS 128
#define MOSUL_BRIDGE_MAX_TRAFFIC_VEHICLES 32
#define MOSUL_BRIDGE_MAX_CONTACTS 64
#define MOSUL_BRIDGE_MAX_INTERACTIONS 128
#define MOSUL_BRIDGE_MAX_MAP_LEVELS 8

typedef struct MosulEngine MosulEngine;

typedef struct {
    char id[MOSUL_BRIDGE_NAME_CAPACITY];
    char image_path[MOSUL_BRIDGE_PATH_CAPACITY];
    char alpha[MOSUL_BRIDGE_NAME_CAPACITY];
    int index;
    float elevation_m;
} MosulMapLevelSummary;

typedef struct {
    uint32_t id;
    char name[MOSUL_BRIDGE_NAME_CAPACITY];
    char sprite_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char selection_marker_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char order_marker_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char route_marker_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char target_marker_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char suppression_marker_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char casualty_marker_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char level_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char target_level_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char topology_node_id[MOSUL_BRIDGE_NAME_CAPACITY];
    int side;
    int order;
    int status;
    float x_m;
    float y_m;
    float target_x_m;
    float target_y_m;
    bool has_target;
    bool hidden;
    bool revealed;
    bool selected;
    bool route_uses_vertical_transition;
    int suppression;
    int morale;
    size_t soldier_count;
    size_t casualty_count;
} MosulUnitSummary;

typedef struct {
    uint32_t id;
    char name[MOSUL_BRIDGE_NAME_CAPACITY];
    char label[MOSUL_BRIDGE_NAME_CAPACITY];
    char marker_id[MOSUL_BRIDGE_NAME_CAPACITY];
    int kind;
    int controlling_side;
    float x_m;
    float y_m;
    float radius_m;
    int value;
} MosulObjectiveSummary;

typedef struct {
    uint32_t id;
    char name[MOSUL_BRIDGE_NAME_CAPACITY];
    char sprite_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char marker_id[MOSUL_BRIDGE_NAME_CAPACITY];
    float x_m;
    float y_m;
    int state;
    int stress;
    int risk;
    bool protected_noncombatant;
} MosulCivilianSummary;

typedef struct {
    uint32_t id;
    char scenario_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char name[MOSUL_BRIDGE_NAME_CAPACITY];
    char sprite_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char level_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char destination_level_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char topology_node_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char route_failure_reason[MOSUL_BRIDGE_NAME_CAPACITY];
    int kind;
    int boarding_mode;
    float x_m;
    float y_m;
    float destination_x_m;
    float destination_y_m;
    bool has_destination;
    float speed_m_per_tick;
    float facing_degrees;
    int seat_capacity;
    int occupied_seats;
    bool active;
    bool blocks_movement;
    bool has_route;
    size_t route_step_count;
    size_t route_step_index;
    int route_total_cost;
    bool route_uses_vertical_transition;
    uint32_t route_failure_count;
} MosulTrafficVehicleSummary;

typedef struct {
    uint32_t id;
    uint32_t tick;
    uint32_t attacker_unit_id;
    uint32_t target_unit_id;
    char marker_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char level_id[MOSUL_BRIDGE_NAME_CAPACITY];
    int kind;
    int side;
    float x_m;
    float y_m;
    float target_x_m;
    float target_y_m;
    int intensity;
    int confidence;
    bool visible;
    bool resolved;
} MosulContactSummary;

typedef struct {
    bool resolved;
    bool visible;
    float distance_m;
    int cover;
    int eligible_shooters;
    int shots_fired;
    int hits;
    int suppression_added;
    int casualties;
    int civilian_risk_added;
} MosulFireResultSummary;

typedef struct {
    uint32_t numeric_id;
    char interaction_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char label[MOSUL_BRIDGE_NAME_CAPACITY];
    char marker_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char state[MOSUL_BRIDGE_NAME_CAPACITY];
    char level_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char target_level_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char topology_node_id[MOSUL_BRIDGE_NAME_CAPACITY];
    char target_node_id[MOSUL_BRIDGE_NAME_CAPACITY];
    int kind;
    int source;
    float x_m;
    float y_m;
    float radius_m;
    float distance_m;
    int priority;
    bool searched;
    bool breached;
    bool open;
    bool vertical;
    bool same_level;
    bool actionable;
    bool route_available;
} MosulInteractionSummary;

typedef struct {
    int objective_points;
    int interaction_points;
    int civilian_risk_penalty;
    int casualty_penalty;
    int time_penalty;
    int total_score;
    int player_casualties;
    int opfor_casualties;
    int civilian_casualties;
    int civilian_risk;
    uint32_t controlled_objectives;
    uint32_t contested_objectives;
    int outcome;
} MosulScoreSummary;

typedef struct {
    MosulScoreSummary score;
    char summary[MOSUL_BRIDGE_TEXT_CAPACITY];
    char narrative[MOSUL_BRIDGE_TEXT_CAPACITY];
} MosulAfterActionSummary;

MosulEngine *MosulEngineCreate(const char *runtime_asset_root);
void MosulEngineDestroy(MosulEngine *engine);

bool MosulEngineReset(MosulEngine *engine);
bool MosulEngineResetBattle(MosulEngine *engine, uint32_t battle_index);
bool MosulEngineStep(MosulEngine *engine, uint32_t steps);
bool MosulEngineRunAI(MosulEngine *engine, uint32_t steps);
bool MosulEngineRunAIForSide(MosulEngine *engine, int side, uint32_t steps);

const char *MosulEngineScenarioName(const MosulEngine *engine);
const char *MosulEngineBriefing(const MosulEngine *engine);
const char *MosulEngineMapName(const MosulEngine *engine);
const char *MosulEngineMapOverviewPath(const MosulEngine *engine);
const char *MosulEngineLastError(const MosulEngine *engine);
uint32_t MosulEngineTick(const MosulEngine *engine);
float MosulEngineMapWidthM(const MosulEngine *engine);
float MosulEngineMapHeightM(const MosulEngine *engine);
uint32_t MosulEngineSelectedUnitID(const MosulEngine *engine);

bool MosulEngineSelectUnit(MosulEngine *engine, uint32_t unit_id);
bool MosulEngineSelectUnitAt(MosulEngine *engine, float x_m, float y_m);
bool MosulEngineClearSelection(MosulEngine *engine);
bool MosulEngineIssueSelectedOrder(MosulEngine *engine, int order);
bool MosulEngineIssueSelectedMove(MosulEngine *engine, float x_m, float y_m);
bool MosulEngineIssueSelectedInvestigate(MosulEngine *engine, float x_m, float y_m);
bool MosulEngineIssueSelectedSearch(MosulEngine *engine, const char *interaction_id);
bool MosulEngineIssueSelectedBreach(MosulEngine *engine, const char *interaction_id);
bool MosulEngineIssueSelectedRouteToInteraction(MosulEngine *engine, const char *interaction_id);
bool MosulEngineSelectedUnitFire(MosulEngine *engine, uint32_t target_unit_id, MosulFireResultSummary *out_result);

size_t MosulEngineCopyMapLevels(const MosulEngine *engine, MosulMapLevelSummary *out_levels, size_t capacity);
size_t MosulEngineCopyUnits(const MosulEngine *engine, MosulUnitSummary *out_units, size_t capacity);
size_t MosulEngineCopyObjectives(const MosulEngine *engine, MosulObjectiveSummary *out_objectives, size_t capacity);
size_t MosulEngineCopyCivilians(const MosulEngine *engine, MosulCivilianSummary *out_civilians, size_t capacity);
size_t MosulEngineCopyTrafficVehicles(
    const MosulEngine *engine,
    MosulTrafficVehicleSummary *out_traffic_vehicles,
    size_t capacity
);
size_t MosulEngineCopyContacts(const MosulEngine *engine, MosulContactSummary *out_contacts, size_t capacity);
size_t MosulEngineCopyInteractions(const MosulEngine *engine, MosulInteractionSummary *out_interactions, size_t capacity);
bool MosulEngineCopyScore(const MosulEngine *engine, MosulScoreSummary *out_score);
bool MosulEngineCopyAfterAction(const MosulEngine *engine, MosulAfterActionSummary *out_report);

#ifdef __cplusplus
}
#endif

#endif
