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
#define MOSUL_BRIDGE_MAX_CONTACTS 64

typedef struct MosulEngine MosulEngine;

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
    uint32_t tick;
    char marker_id[MOSUL_BRIDGE_NAME_CAPACITY];
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

MosulEngine *MosulEngineCreate(const char *moderner_krieg_root);
void MosulEngineDestroy(MosulEngine *engine);

bool MosulEngineReset(MosulEngine *engine);
bool MosulEngineResetBattle(MosulEngine *engine, uint32_t battle_index);
bool MosulEngineStep(MosulEngine *engine, uint32_t steps);
bool MosulEngineRunAI(MosulEngine *engine, uint32_t steps);

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

size_t MosulEngineCopyUnits(const MosulEngine *engine, MosulUnitSummary *out_units, size_t capacity);
size_t MosulEngineCopyObjectives(const MosulEngine *engine, MosulObjectiveSummary *out_objectives, size_t capacity);
size_t MosulEngineCopyCivilians(const MosulEngine *engine, MosulCivilianSummary *out_civilians, size_t capacity);
size_t MosulEngineCopyContacts(const MosulEngine *engine, MosulContactSummary *out_contacts, size_t capacity);
bool MosulEngineCopyScore(const MosulEngine *engine, MosulScoreSummary *out_score);
bool MosulEngineCopyAfterAction(const MosulEngine *engine, MosulAfterActionSummary *out_report);

#ifdef __cplusplus
}
#endif

#endif
