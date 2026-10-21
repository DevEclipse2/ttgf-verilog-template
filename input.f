# --- Include Directories (for `include files) ---
+incdir+./src/macros
+incdir+./src/main
+incdir+./src/onboardController
+incdir+./src/utils

# --- Library Search Directories (for automatic module finding) ---
-y ./src/macros/control
-y ./src/macros/logic
-y ./src/macros/register
-y ./src/main/alu
-y ./src/main/thread
-y ./src/onboardController
-y ./src/utils

# --- Source Files (Top-levels or individual files) ---
./src/main/tt_um_triple_t.v
./src/utils/coresetup.v
./src/utils/logic_container.v
