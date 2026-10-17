dofile(MOCK)
LOADMOD(ROOT)
local A = ALifeCamp
local Camp, Build, Plan, Bp, Districts = A.Camp, A.Build, A.Plan, A.Blueprints, A.Districts
MOCKALIFE()
for x = 100, 260 do for y = 100, 240 do NEWSQUARE(x, y, 0) end end
PLAYER = NEWPLAYER(0)
HOURS = 300
local camp = Camp.create({ x1 = 120, y1 = 120, x2 = 220, y2 = 200, z = 0 }, "Town")
camp.phase = "plan"
local t0 = os.clock()
Plan.generate(camp)
check("fast", os.clock() - t0 < 20)
local list = Build.list(camp)
local decor, total = 0, 0
for _, p in ipairs(list) do
    total = total + 1
    if Districts.isDecor(p.kind) then decor = decor + 1 end
    check("kind registered " .. p.kind, Bp.kinds[p.kind] ~= nil)
end
check("decor projects exist", decor >= 5, decor)
local clash = false
for i = 1, #list do
    for j = i + 1, #list do
        if list[i].kind ~= "fence" and list[j].kind ~= "fence" and Build.overlaps(Bp.footprint(list[i]), Bp.footprint(list[j])) then clash = true end
    end
end
check("no overlaps", not clash)
check("describe", #Districts.describe(camp) >= 1)
local n0 = #Build.list(camp)
local again = Plan.generate(camp)
local kinds = {}
for i = n0 + 1, #Build.list(camp) do kinds[#kinds + 1] = Build.list(camp)[i].kind end
local third = Plan.generate(camp)
local fourth = Plan.generate(camp)
check("converges", fourth == 0, again .. "," .. third .. "," .. fourth)
local stagesOk = true
for _, p in ipairs(list) do
    local ok, st = pcall(Bp.kinds[p.kind].build, p)
    if not ok or type(st) ~= "table" then stagesOk = false end
end
check("stages build", stagesOk)
RESULT = { log = LOG, fails = FAILS, silent = SILENT, missing = {} }
