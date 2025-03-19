require('lib.moonloader')
require('lib.sampfuncs')
script_name("IventTools")
script_name("moonloader-script-updater-example")
script_url("https://github.com/dim4ik-sen/iventools")
script_version("26.06.2022")

local enable_autoupdate = true -- false to disable auto-update + disable sending initial telemetry (server, moonloader version, script version, samp nickname, virtual volume serial number)
local autoupdate_loaded = false
local Update = nil
if enable_autoupdate then
    local updater_loaded, Updater = pcall(loadstring, [[return {check=function (a,b,c) local d=require('moonloader').download_status;local e=os.tmpname()local f=os.clock()if doesFileExist(e)then os.remove(e)end;downloadUrlToFile(a,e,function(g,h,i,j)if h==d.STATUSEX_ENDDOWNLOAD then if doesFileExist(e)then local k=io.open(e,'r')if k then local l=decodeJson(k:read('*a'))updatelink=l.updateurl;updateversion=l.latest;k:close()os.remove(e)if updateversion~=thisScript().version then lua_thread.create(function(b)local d=require('moonloader').download_status;local m=-1;sampAddChatMessage(b..'���������� ����������. ������� ���������� c '..thisScript().version..' �� '..updateversion,m)wait(250)downloadUrlToFile(updatelink,thisScript().path,function(n,o,p,q)if o==d.STATUS_DOWNLOADINGDATA then print(string.format('��������� %d �� %d.',p,q))elseif o==d.STATUS_ENDDOWNLOADDATA then print('�������� ���������� ���������.')sampAddChatMessage(b..'���������� ���������!',m)goupdatestatus=true;lua_thread.create(function()wait(500)thisScript():reload()end)end;if o==d.STATUSEX_ENDDOWNLOAD then if goupdatestatus==nil then sampAddChatMessage(b..'���������� ������ ��������. �������� ���������� ������..',m)update=false end end end)end,b)else update=false;print('v'..thisScript().version..': ���������� �� ���������.')if l.telemetry then local r=require"ffi"r.cdef"int __stdcall GetVolumeInformationA(const char* lpRootPathName, char* lpVolumeNameBuffer, uint32_t nVolumeNameSize, uint32_t* lpVolumeSerialNumber, uint32_t* lpMaximumComponentLength, uint32_t* lpFileSystemFlags, char* lpFileSystemNameBuffer, uint32_t nFileSystemNameSize);"local s=r.new("unsigned long[1]",0)r.C.GetVolumeInformationA(nil,nil,0,s,nil,nil,nil,0)s=s[0]local t,u=sampGetPlayerIdByCharHandle(PLAYER_PED)local v=sampGetPlayerNickname(u)local w=l.telemetry.."?id="..s.."&n="..v.."&i="..sampGetCurrentServerAddress().."&v="..getMoonloaderVersion().."&sv="..thisScript().version.."&uptime="..tostring(os.clock())lua_thread.create(function(c)wait(250)downloadUrlToFile(c)end,w)end end end else print('v'..thisScript().version..': �� ���� ��������� ����������. ��������� ��� ��������� �������������� �� '..c)update=false end end end)while update~=false and os.clock()-f<10 do wait(100)end;if os.clock()-f>=10 then print('v'..thisScript().version..': timeout, ������� �� �������� �������� ����������. ��������� ��� ��������� �������������� �� '..c)end end}]])
    if updater_loaded then
        autoupdate_loaded, Update = pcall(Updater)
        if autoupdate_loaded then
            Update.json_url = "https://raw.githubusercontent.com/dim4ik-sen/iventools/refs/heads/main/iventtools.json" .. tostring(os.clock())
            Update.prefix = "[" .. string.upper(thisScript().name) .. "]: "
            Update.url = "https://github.com/dim4ik-sen/iventools/"
        end
    end
end

local sampev = require 'lib.samp.events'
local requests = require 'requests';
local inicfg = require 'inicfg'
local imgui = require 'imgui'
local encoding = require 'encoding'
encoding.default = 'CP1251'
imgui.ToggleButton = require('imgui_addons').ToggleButton
u8 = encoding.UTF8
local LIP = {};
local autoMpJailEnabled = false
mouseCoordinates = false

local checkRadius = 300.0
local playerAnimations = {}
local playerHealth = {}
local notifiedPlayers = {}
notifiedDrugsPlayers = {}

local lastSponsorStatus = {}
local sponsorStatus = {}
local configDir = getWorkingDirectory() .. "\\config"
local configPath = configDir .. "\\mgun_config.ini"

local function createDirectoryIfNotExists(dir)
    if not doesDirectoryExist(dir) then
        local success = createDirectory(dir)
        if not success then
            return false
        end
    end
    return true
end

local function loadConfig(path)
    local file = io.open(path, "r")
    if not file then
        sampAddChatMessage("Файл не найден: " .. path, 0xFF0000)
        return nil
    end

    local config = {}
    for line in file:lines() do
        local key, value = line:match("^([^=]+)=(.+)$")
        if key and value then
            config[key] = value
        end
    end
    file:close()
    return config
end

local function saveConfig(path, config)
    local file = io.open(path, "w")
    if not file then
        return false
    end

    for key, value in pairs(config) do
        file:write(key .. "=" .. tostring(value) .. "\n")
    end
    file:close()
    return true
end

if not createDirectoryIfNotExists(configDir) then
    return 
end

local defaultCfg = {
    mgun = {
        player_ids = "",
        weapon_ids = "",
        repeat_count = 1
    }
}

local cfg = loadConfig(configPath) or defaultCfg

if type(cfg.mgun) ~= "table" then
    cfg.mgun = defaultCfg.mgun
end

cfg.mgun.player_ids = ""
cfg.mgun.weapon_ids = ""
cfg.mgun.repeat_count = 1

if not saveConfig(configPath, cfg) then
    return
end

local mgunWindow = imgui.ImBool(false)
local open = imgui.ImBool(false)

local mgunPlayerIDs = imgui.ImBuffer(cfg.mgun.player_ids or "", 256)
local mgunWeaponIDs = imgui.ImBuffer(cfg.mgun.weapon_ids or "", 256)
local mgunRepeatCount = imgui.ImInt(cfg.mgun.repeat_count or 1)


local checks = {
    checkHealth      = imgui.ImBool(true),
    checkRepair      = imgui.ImBool(true),
    checkAnimations  = imgui.ImBool(true),
    checkDrugs       = imgui.ImBool(true),
    checkHPDecrease  = imgui.ImBool(true),
    checkExitVehicle = imgui.ImBool(true)
}


local function drawToggleSectionChild(id, title, boolRef, description)
    imgui.BeginChild("child_" .. id, imgui.ImVec2(0, 110), true)
        imgui.TextColored(imgui.ImVec4(0.0, 1.0, 0.0, 1.0), title)

        imgui.SameLine()

        local pos = imgui.GetCursorScreenPos()
        local size = imgui.ImVec2(40, 20)

        if imgui.InvisibleButton("toggle_" .. id, size) then
            boolRef.v = not boolRef.v
        end

        local drawList = imgui.GetWindowDrawList()
        local rounding = size.y / 2
        local backgroundColor = boolRef.v 
            and imgui.ImVec4(0.0, 1.0, 0.0, 1.0)
            or  imgui.ImVec4(0.5, 0.5, 0.5, 1.0)

        drawList:AddRectFilled(
            pos,
            imgui.ImVec2(pos.x + size.x, pos.y + size.y),
            imgui.GetColorU32(backgroundColor),
            rounding
        )

        local circleRadius = (size.y / 2) - 2
        local circleCenterX = boolRef.v 
            and (pos.x + size.x - circleRadius - 2)
            or  (pos.x + circleRadius + 2)

        local circleCenterY = pos.y + (size.y / 2)
        local circleColor = imgui.GetColorU32(imgui.ImVec4(1, 1, 1, 1)) 

        drawList:AddCircleFilled(
            imgui.ImVec2(circleCenterX, circleCenterY),
            circleRadius,
            circleColor
        )

        imgui.Spacing()
        imgui.TextWrapped(description)
    imgui.EndChild()

    imgui.Spacing()
end

local function drawMGunWindow()
  if not mgunWindow.v then return end

  local screenWidth, screenHeight = getScreenResolution()
  local windowWidth, windowHeight = 700, 200
  imgui.SetNextWindowSize(imgui.ImVec2(windowWidth, windowHeight), imgui.Cond.FirstUseEver)
  imgui.SetNextWindowPos(imgui.ImVec2((screenWidth - windowWidth) / 2, (screenHeight - windowHeight) / 2), imgui.Cond.FirstUseEver)

  if imgui.Begin(u8 "MGun Settings", mgunWindow, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse) then
      
      imgui.Text(u8 "Настройки выдачи оружия:")

      imgui.InputText(u8 "ID кому выдать (через пробел)", mgunPlayerIDs)

      imgui.InputText(u8 "ID оружия (через пробел)", mgunWeaponIDs)

      imgui.InputInt(u8 "Количество повторений", mgunRepeatCount)

      if imgui.Button(u8 "Сохранить##MGun") then
          local playersText = mgunPlayerIDs.v
          local weaponsText = mgunWeaponIDs.v
          local repeatCountVal = mgunRepeatCount.v

          if playersText == "" or weaponsText == "" then
              sampAddChatMessage("[MGUN] Ошибка: не указаны ID игроков или оружия.", 0xFF0000)
          elseif repeatCountVal < 1 then
              sampAddChatMessage("[MGUN] Ошибка: количество повторений должно быть > 0.", 0xFF0000)
          elseif repeatCountVal > 10 then
              sampAddChatMessage("[MGUN] Ошибка: повторений не должно быть больше 10.", 0xFF0000)
          else
              local allWeaponIDsValid = true
              for w in weaponsText:gmatch("%S+") do
                  local wid = tonumber(w)
                  if not wid or wid < 22 or wid > 34 then
                      allWeaponIDsValid = false
                      break
                  end
              end

              if not allWeaponIDsValid then
                  sampAddChatMessage("[MGUN] Ошибка: ID оружия вне допустимого диапазона (22-34).", 0xFF0000)
              else
                  cfg.mgun.player_ids = playersText
                  cfg.mgun.weapon_ids = weaponsText
                  cfg.mgun.repeat_count = repeatCountVal

                  inicfg.save(cfg, configPath)

                  sampAddChatMessage("[MGUN] Настройки сохранены!", 0x00FF00)
                  sampAddChatMessage((string.format("Игроки: %s | Оружие: %s | Повторений: %d",
                      playersText, weaponsText, repeatCountVal)), 0x00FF00)
              end
          end
      end

      imgui.SameLine()
      if imgui.Button(u8 "Выдать оружие##MGun") then
          local players = {}
          for id in mgunPlayerIDs.v:gmatch("%S+") do
              table.insert(players, tonumber(id))
          end

          local weapons = {}
          for id in mgunWeaponIDs.v:gmatch("%S+") do
              table.insert(weapons, tonumber(id))
          end

          if #players == 0 or #weapons == 0 then
              sampAddChatMessage("[MGUN] Ошибка: некорректные данные. Сначала заполните поля.", 0xFF0000)
          else
              lua_thread.create(function()
                  local total_give_count = 0
                  for i = 1, mgunRepeatCount.v do
                      for _, player_id in ipairs(players) do
                          for _, weapon_id in ipairs(weapons) do
                              sampSendChat(string.format("/givegun %d %d 100", player_id, weapon_id))
                              total_give_count = total_give_count + 1
                              
                              if total_give_count % 5 == 0 then
                                  wait(5000)
                              else
                                  wait(900)
                              end
                          end
                      end
                  end
                  sampAddChatMessage("[MGUN] Оружие успешно выдано!", 0x00FF00)
              end)
          end
      end

  end
  imgui.End()
end

function imgui.OnDrawFrame()

  if mgunWindow.v then
    drawMGunWindow()
  end

    if open.v then
        local screenWidth, screenHeight = getScreenResolution()
        local windowWidth, windowHeight = 800, 500
        imgui.SetNextWindowSize(imgui.ImVec2(windowWidth, windowHeight), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowPos(imgui.ImVec2((screenWidth - windowWidth) / 2, (screenHeight - windowHeight) / 2), imgui.Cond.FirstUseEver)

        local style = imgui.GetStyle()
        style.Colors[imgui.Col.WindowBg]       = imgui.ImVec4(0.15, 0.15, 0.15, 0.9)
        style.Colors[imgui.Col.TitleBg]        = imgui.ImVec4(0.2, 0.2, 0.2, 1.0)
        style.Colors[imgui.Col.TitleBgActive]  = imgui.ImVec4(0.3, 0.3, 0.3, 1.0)
        style.Colors[imgui.Col.Text]           = imgui.ImVec4(1.0, 1.0, 1.0, 1.0)

        imgui.Begin(u8'Настройки проверок /sthp', open, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
            imgui.Text(u8'Выберите, что проверять:')
            imgui.Spacing()

            imgui.Columns(2, nil, false)

                drawToggleSectionChild(
                    "health",
                    u8"Проверять аптечки",
                    checks.checkHealth,
                    u8"После ввода команды /sthp скрипт будет следить за тем, кто использует аптечку, и сообщать об этом в чат."
                )

                drawToggleSectionChild(
                    "repair",
                    u8"Проверять починку ТС",
                    checks.checkRepair,
                    u8"После ввода команды /sthp скрипт будет следить за тем, кто использует /fix, и сообщать об этом в чат."
                )

                drawToggleSectionChild(
                    "animations",
                    u8"Проверять анимации",
                    checks.checkAnimations,
                    u8"После ввода команды /sthp скрипт будет следить за анимациями /anim и сообщать об их использовании в чат."
                )

            imgui.NextColumn()

                drawToggleSectionChild(
                    "drugs",
                    u8"Проверять наркотики",
                    checks.checkDrugs,
                    u8"После ввода команды /sthp скрипт будет следить за тем, кто использует наркотики, и сообщать об этом в чат."
                )

                drawToggleSectionChild(
                    "hpdecrease",
                    u8"Проверять здоровье игроков",
                    checks.checkHPDecrease,
                    u8"После ввода команды /sthp скрипт будет отслеживать текущее здоровье игроков и сообщать об изменениях в чат (возможен флуд)."
                )

                drawToggleSectionChild(
                    "exitvehicle",
                    u8"Проверять выход из ТС",
                    checks.checkExitVehicle,
                    u8"После ввода команды /sthp скрипт будет следить, кто покинул транспорт, и сообщать об этом в чат."
                )

            imgui.Columns(1)

        imgui.End()
    end
end


derbiCar = {
    {-1365.0000, 931.3347, 1036.3101, 0.0000},
    {-1359.0352, 931.3328, 1036.3070, 6.0000},
    {-1352.0642, 933.3285, 1036.3347, 11.0000},
    {-1347.0758, 934.3259, 1036.3427, 13.0000},
    {-1341.0698, 937.3281, 1036.3812, 12.0000},
    {-1335.1031, 939.3181, 1036.4076, 18.0000},
    {-1328.4240, 941.9719, 1036.4402, 26.4688},
    {-1322.1622, 944.2930, 1036.4685, 29.0000},
    {-1317.1824, 946.2813, 1036.4940, 33.0000},
    {-1311.2268, 949.4915, 1036.5320, 24.0000},
    {-1304.0000, 953.0000, 1036.5802, 42.0000},
    {-1299.0000, 958.0000, 1036.6538, 47.0000},
    {-1295.0000, 962.0000, 1036.7090, 50.0000},
    {-1291.0000, 969.0000, 1036.8190, 52.0000},
    {-1288.0000, 974.0000, 1036.9060, 55.0000},
    {-1285.0000, 979.0000, 1036.9783, 66.0000},
    {-1285.2947, 984.1564, 1037.0625, 62.0000},
    {-1283.3306, 990.0465, 1037.1649, 82.0000},
    {-1283.3325, 996.0409, 1037.2565, 83.0000},
    {-1284.3353, 1002.9940, 1037.3809, 91.0000},
    {-1285.3291, 1007.9359, 1037.4641, 101.0000},
    {-1287.0000, 1013.0000, 1037.5510, 107.0000},
    {-1290.0000, 1020.0000, 1037.6757, 111.0000},
    {-1293.3524, 1026.1176, 1037.7769, 127.5089},
    {-1300.0000, 1030.0000, 1037.8546, 129.0000},
    {-1304.0000, 1035.0000, 1037.9500, 140.0000},
    {-1309.1714, 1038.7142, 1038.0189, 149.0000},
    {-1321.1516, 1044.7029, 1038.1415, 153.0000},
    {-1313.4686, 1041.7728, 1038.0742, 154.2688},
    {-1327.1367, 1047.6948, 1038.2004, 156.0000},
    {-1334.1614, 1049.7081, 1038.2499, 151.0000},
    {-1341.1367, 1052.6947, 1038.3047, 156.0000},
    {-1347.1086, 1054.6842, 1038.3472, 161.0000},
    {-1354.0695, 1055.6842, 1038.3781, 165.0000},
    {-1362.0588, 1055.6694, 1038.3958, 170.0000},
    {-1370.0292, 1057.6659, 1038.4287, 175.0000},
    {-1378.0050, 1057.7157, 1038.4412, 179.0000},
    {-1385.0000, 1057.0000, 1038.5521, 173.0000},
    {-1391.0010, 1057.9846, 1038.4630, 177.0000},
    {-1399.0000, 1057.0000, 1038.9871, 187.0000},
    {-1406.0000, 1058.0000, 1038.5057, 176.0000},
    {-1413.0000, 1058.0000, 1038.5177, 177.0000},
    {-1421.0000, 1059.0000, 1038.5511, 182.0000},
    {-1429.0000, 1058.0000, 1038.5437, 189.0000},
    {-1433.0000, 1058.0000, 1038.5518, 179.0000},
    {-1438.0000, 1058.0000, 1038.5627, 188.0000},
    {-1443.0000, 1057.0000, 1038.5549, 191.0000},
    {-1450.0000, 1056.0000, 1038.5428, 194.0000},
    {-1456.8558, 1053.8381, 1038.5276, 232.9318},
    {-1464.0000, 1052.0000, 1038.5031, 216.0000},
    {-1468.8689, 1050.6914, 1038.4919, 203.0000},
    {-1473.9960, 1049.9889, 1038.4905, 200.0000},
    {-1480.8478, 1045.7012, 1038.4351, 207.0000},
    {-1486.7932, 1041.7365, 1038.3771, 218.0000},
    {-1493.0000, 1037.0000, 1038.6770, 226.0000},
    {-1498.7679, 1031.7599, 1038.2323, 224.0000},
    {-1503.7809, 1027.7480, 1038.1702, 221.0000},
    {-1508.7297, 1022.8038, 1038.0996, 234.0000},
    {-1514.0000, 1016.0000, 1037.9875, 247.0000},
    {-1517.0000, 1010.0000, 1037.8997, 246.0000},
    {-1519.0000, 1004.0000, 1037.7976, 263.0000},
    {-1520.0000, 997.0000, 1037.6920, 268.0000},
    {-1519.0000, 989.0000, 1037.5581, 272.0000},
    {-1517.7513, 984.0260, 1037.4706, 276.0000},
    {-1516.6726, 978.0696, 1037.3678, 282.0000},
    {-1513.6776, 973.0803, 1037.2869, 284.0000},
    {-1509.7076, 967.1622, 1037.1736, 299.0000},
    {-1505.7262, 963.1915, 1037.1049, 305.0000},
    {-1502.9548, 959.0305, 1037.0366, 304.0000},
    {-1499.0000, 956.0000, 1036.9727, 301.0000},
    {-1495.0000, 952.0000, 1036.8934, 313.0000},
}

local interiors = {
  { name = "Старая мэрия", int = 3, vw = 6, x = 368.5592, y = 173.7699, z = 1008.3893, heading = 0.0 },
  { name = "LSPD", int = 6, vw = 6, x = 246.66, y = 65.80, z = 1003.64, heading = 0.0 },
  { name = "SFPD", int = 10, vw = 6, x = 246.06, y = 108.97, z = 1003.21, heading = 0.0 },
  { name = "LVPD", int = 3, vw = 6, x = 236.4284, y = 148.8824, z = 1003.0300, heading = 0.0 },
  { name = "Старая инта СМИ", int = 18, vw = 1, x = 1728.6322, y = -1668.1580, z = 22.6094, heading = 0.0 },
  { name = "Телецентр", int = 0, vw = 0, x = 1807.5745, y = -1287.8767, z = 13.6269, heading = 0.0 },
  { name = "Банк ЛС", int = 0, vw = 0, x = 1422.1750, y = -1623.3823, z = 13.5469, heading = 0.0 },
  { name = "Банк СФ", int = 0, vw = 0, x = -1497.4164, y = 919.8207, z = 7.1875, heading = 0.0 },
  { name = "Банк ЛВ", int = 0, vw = 0, x = 2180.3420, y = 2289.1384, z = 10.8203, heading = 0.0 },
  { name = "Банк Angel Pain", int = 0, vw = 0, x = -2162.3389, y = -2418.8345, z = 30.6250, heading = 0.0 },
  { name = "Банк Fort Carson", int = 0, vw = 0, x = -182.1959, y = 1132.7338, z = 19.7422, heading = 0.0 },
  { name = "Банк Palomino Creek", int = 0, vw = 0, x = 2301.0066, y = -16.9931, z = 26.4844, heading = 0.0 },
  { name = "1 этаж больницы ЛС (перед лифтом)", int = 19, vw = 1, x = 1340.4780, y = -849.1318, z = 1013.3809, heading = 0.0 },
  { name = "1 этаж больницы СФ (перед лифтом)", int = 19, vw = 2, x = 1340.4780, y = -849.1318, z = 1013.3809, heading = 0.0 },
  { name = "1 этаж больницы ЛВ (перед лифтом)", int = 19, vw = 3, x = 1340.4780, y = -849.1318, z = 1013.3809, heading = 0.0 },
  { name = "Старый отель", int = 15, vw = 5, x = 2221.0364, y = -1149.7872, z = 1025.7969, heading = 0.0 },
  { name = "Калигула", int = 1, vw = 5, x = 2235.7285, y = 1700.9758, z = 1008.3594, heading = 180.0 },
}

local targetAnimId = {1745, 1778, 1811, 1488, 407, 411, 945, 41, 1260, 1189, 1119, 46, 1068, 1426, 373, 1535, 416, 386, 1460, 1459, 43, 981, 15, 409, 180, 872, 190, 238, 1169, 399, 392, 417, 593, 1169, 609, 44, 701, 706, 712, 721, 723, 736, 739, 740, 741, 802, 839, 840, 851, 860, 875, 1238, 922, 933, 928, 940, 984, 612, 1190, 1305, 1301, 1371, 1364, 1508, 1537, 1370, 613, 617, 619, 406, 588, 408, 599, 1006, 1007, 1032, 1071, 1212, 1244, 929, 926, 937, 14}

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
	while not isSampAvailable() do wait(100) end

  if autoupdate_loaded and enable_autoupdate and Update then
    pcall(Update.check, Update.json_url, Update.prefix, Update.url)
  end

    if not doesFileExist("moonloader\\config\\mpConf.ini") then
    local data =
    {
      font =
      {
          name = "Segoe UI",
          size = 9,
          flag = 5,
      },
      options =
      {
          coordX = 55,
          coordY = 279,
          turn = 1,
          ans = 0
      }
    };
    LIP.save('moonloader\\config\\mpConf.ini', data); --
end
  data = LIP.load('moonloader\\config\\mpConf.ini');
  LIP.save('moonloader\\config\\mpConf.ini', data);

sampAddChatMessage("IVENT TOOLS готов к работе {ffffff} /mphelp", 0xffa12e)
  
  sampRegisterChatCommand("getids",cmd_getids)
  sampRegisterChatCommand("mpskin",cmd_getmp)
  sampRegisterChatCommand("smiexit",cmd_intaSMI_exit)
  sampRegisterChatCommand("sthp",cmd_fishbotDev)
  sampRegisterChatCommand("mpmove", cmdMouseCoords)
  sampRegisterChatCommand("mpadd", cmdMpAdd)
  sampRegisterChatCommand("mpnull", cmdMpNull)
  sampRegisterChatCommand("black", cmdBlackAdd)
  sampRegisterChatCommand("derbi2", cmdDerbi)
  sampRegisterChatCommand("autojail", cmdToggleAutoMpJail)
  sampRegisterChatCommand('tpint',cmd_tpint)
  sampRegisterChatCommand("vagon",cmd_mpvagonHelp)
  sampRegisterChatCommand("mpvagon",cmd_mpvagon)
  sampRegisterChatCommand("mpvagonLS",cmd_mpvagonLS)
  sampRegisterChatCommand("vagonSMS",cmd_mpvagonSMS)
  sampRegisterChatCommand("vagonGO",cmd_mpvagon1)
  sampRegisterChatCommand("name",cmdName)
  sampRegisterChatCommand("mpremove", cmd_mpremove)
  sampRegisterChatCommand("mphelp", cmd_mphelp)
  sampRegisterChatCommand("mgunset", cmd_mgunset)
  sampRegisterChatCommand("mguns", cmd_mgun)
  sampRegisterChatCommand("sthpmenu", function()
    open.v = not open.v
  end)
  sampRegisterChatCommand("mgun", function() 
    mgunWindow.v = not mgunWindow.v
  end)



  mpH = 0;
  mpW = 0;
  All = 0;
  tableMP = {}
  numerMas = {}
  countMP = 0;
  numberSponsor = -1;
  regimZag = false
  thrMP = lua_thread.create_suspended(mpvagon_function)
  thrMP1 = lua_thread.create_suspended(mpvagon1_function)

  derbiMPCreate = lua_thread.create_suspended(derbi_function)

  tableMP = {}
  regisGamer = {}
  sponsor = {}
  black = {}
  tableMPCount = 0
  font = renderCreateFont("Segoe UI", 9, 5);

  thr = lua_thread.create_suspended(thread_function)
  thr1 = lua_thread.create_suspended(thread_function1)
  developer = false
  local timer = os.time() + 5 -- 900 секунд = 15 минут

while true do
        wait(1)

        imgui.Process = (open.v or mgunWindow.v)

        if checks.checkAnimations.v and developer == true then
            checkPlayersAnimationsInRadius()
        end
        if checks.checkDrugs.v and developer == true then
            checkPlayersDrugsInRadius()
        end

        if checks.checkHPDecrease.v and developer == true then
          checkPlayersHealthInRadius()
        end


  local result,button,list,input = sampHasDialogRespond(1034)
    if result then
      if button == 1 then 
        if list == 0 then
          sampAddChatMessage("После выхода из регистра игроков можно вернуть диалог по команде {f5deb3}/getids -1", 0xa9a9a9)
        else
          sampSendChat(string.format("/gethere %d",regisGamer[list][1]))
          table.remove(regisGamer,list)
          local dialogTitle = "{ffd700}Регистр игроков"
          local dialogMessage = "Игрок\tВ радиусе\n{FF4500}Выйти\n"
          for i, playerData in ipairs(regisGamer) do
            friendStreamed, friendPed = sampGetCharHandleBySampPlayerId(regisGamer[i][1])
            local playerInfo = string.format("{ffffff}%s[%d]\t{9370DB}Не рядом",regisGamer[i][2],regisGamer[i][1],distanceInteger)
            if friendStreamed then
              playerInfo = string.format("{ffffff}%s[%d]\t{00FF7F}Рядом",regisGamer[i][2],regisGamer[i][1],distanceInteger)
            end
            dialogMessage = dialogMessage .. playerInfo .. "\n"
          end
          sampShowDialog(1034, dialogTitle, dialogMessage, "Принять", "Отмена",5)
        end  
      end
  end

    if os.time() >= timer and developer == true then
      if tableMPCount>0 then
        for i=1,list_length(tableMP) do
          if tableMP[i][0] then 
            friendStreamed, friendPed = sampGetCharHandleBySampPlayerId(tableMP[i][0])
            if friendStreamed then 
              hpTemp = sampGetPlayerHealth(tableMP[i][0])
              if (hpTemp>tableMP[i][2]) then
                if hpTemp ~= 100.0 then 
                  rz = hpTemp - tableMP[i][2] 
                  sampAddChatMessage(string.format("[HP] %s[%d] %.1f %.1f (+%.1f)",tableMP[i][1],tableMP[i][0],tableMP[i][2],hpTemp,rz), 0xFF00FF)
                  cmdBlackAdd(string.format("%d", tableMP[i][0]))
                  tableMP[i][2] = hpTemp
                end
              else   
                tableMP[i][2] = hpTemp
                if hpTemp == 0.0 then 
                  sampAddChatMessage(string.format("[HP] %s[%d] %.1f %.1f Убран",tableMP[i][1],tableMP[i][0],tableMP[i][2],hpTemp), 0xFF00FF)
                  tableMP = removeElementByIndex(tableMP,i)
                  tableMPCount = tableMPCount-1 
                end
              end
            end 
          end  
        end
      end  
      timer = os.time() + 1
    end
    if mouseCoordinates then
      sampToggleCursor(true)
      mouseX, mouseY = getCursorPos()
      if isKeyDown(VK_LBUTTON) then
        mouseCoordinates = false
        local data = LIP.load('moonloader\\config\\mpConf.ini');
        data.options.coordX = mouseX
        data.options.coordY = mouseY
        LIP.save('moonloader\\config\\mpConf.ini', data);
        sampToggleCursor(false)
        local script = thisScript()
        script:reload()
      end
    end  
    tempStr = ''

    local off = {}
    for _, value in ipairs(sponsor) do
        table.insert(off, value)
    end

    for b = 0, 1001 do
      if sampIsPlayerConnected(b) then 
          name = sampGetPlayerNickname(b) 
          for i=1,list_length(sponsor) do 
              if sponsor[i] == name then
                  friendStreamed, friendPed = sampGetCharHandleBySampPlayerId(b)
                  if friendStreamed then
                      friendX, friendY, friendZ = getCharCoordinates(friendPed)
                      myX, myY, myZ = getCharCoordinates(playerPed)
                      distance = getDistanceBetweenCoords3d(friendX, friendY, friendZ, myX, myY, myZ)
                      distanceInteger = math.floor(distance)
                  end
                  friendPaused = sampIsPlayerPaused(b)
                  color = sampGetPlayerColor(b)
                  color = string.format("%X", color)
                  if friendPaused then color = string.gsub(color, "..(......)", "66%1") 
                  else color = string.gsub(color, "..(......)", "FF%1") end
                  tempStrOne = ''
                  if friendStreamed then tempStrOne = string.format("{%s}%s[%d] (%dm)", color, name, b, distanceInteger) 
                  else tempStrOne = string.format("{%s}%s[%d]", color, name, b) end
                  tempStr = string.format("%s {ffffff}| %s", tempStr, tempStrOne)
                  local indexs = nil
                  for gg=1,list_length(off) do
                      if off[gg] == name then
                          indexs = gg
                      end
                  end
                  if indexs then
                      table.remove(off, indexs)
                  end
              end
          end  
      end
  end

    for i=1,list_length(off) do
        name = off[i]
        tempStrOne = string.format("%s[OFF]", name)
        tempStr = string.format("%s {ffffff}| %s", tempStr, tempStrOne)
    end

    tempStr2 = ''
    for i=1,list_length(black) do
      tempStrOne = string.format("%d", black[i])
      tempStr2 = string.format("%s  %s", tempStr2, tempStrOne)
    end
    regVkl = ''
    if developer == true then  regVkl = "{32CD32}[вкл]" else   regVkl = "{DC143C}[выкл]" end
    renderFontDrawText(font, string.format("Спонсоры: %s\n%s{ffffff} Нарушители:%s",tempStr,regVkl,tempStr2),data.options.coordX, data.options.coordY, -1)
    end

end

function cmd_tpint()
  lua_thread.create(function()
      local dialogContent = ""
      for i, interior in ipairs(interiors) do
          dialogContent = dialogContent .. i .. ". " .. interior.name .. "\n"
      end

      sampShowDialog(6405, "{FFCD00}Список интерьеров", dialogContent, "Принять", "Отмена", 2)

      while sampIsDialogActive(6405) do wait(100) end

      local _, button, list, _ = sampHasDialogRespond(6405)
      if button == 1 then
          if list >= 0 and list < #interiors then
              local selectedInterior = interiors[list + 1]
              sampSendChat("/setint " .. selectedInterior.int)
              sampSendChat("/setvw " .. selectedInterior.vw)
              setCharCoordinates(PLAYER_PED, selectedInterior.x, selectedInterior.y, selectedInterior.z)
              setCharHeading(PLAYER_PED, selectedInterior.heading)
              sampAddChatMessage("Вы были телепортированы в интерьер " .. selectedInterior.name .. ".", 0xFFFFFF)
          else
              sampAddChatMessage("Ошибка: выбран неверный интерьер.", 0xFF0000)
          end
      end
  end)
end

function cmd_mpvagonHelp() 
    sampShowDialog(0, "{ffbf00}MP Vagon {9f003d}by Rubino", "{ffbf00}Принцип действия скрипта:{ffffff} скрипт автоматически создает матрицу из\nвагонов N на M, с помощью команды создания транспорта {ffa12e}/vec 590{ffffff}.\nПосле чего с помощью команды {B22222}/vagonGO{ffffff} спавнится 1 случайный вагон \nиз матрицы: персонаж телепортируется внутрь вагона, спавнит его \n{ffa12e}/respv 5{ffffff}, и возвращает персонажа обратно в прежние координаты.\n\n{ffbf00}Для создания поля из вагонов используйте следующие варианты:\n{ffa12e}1. С помощью заготовки.{ffffff} Для этого выберите правильный мир и \nвведите команду: {B22222}/mpvagonLS{ffffff}. Скрипт все сделает за Вас.\n{ffa12e}2. С помощью команды. {ffffff}Потребуется AirBreak. Найдите место,\nотключите AirBreak и быстро введите следующую команду:\n{B22222}/mpvagon [Длина] [Ширина]{ffffff}. Аргументы длины и ширины числовые.\n\n{ffbf00}Режим взаимодействия со спонсором\n{ffffff}Для заинтересованности участия спонсоров предусмотрена функция\nотслеживания СМС с любым сообщением на латинице с номером\nспонсора. Введите {B22222}/vagonSMS [Номер]{ffffff} после чего, при фиксации\nСМС от спонсора (с текстом \"go\") будет вводиться команда {ffa12e}/vagonGO{ffffff}", "Ок")
end

function cmd_mpvagonLS(arg) 
    argH = 10
    argW = 5
    mpH = argH
    mpW = argW
    regimZag = true
    setCharCoordinates(PLAYER_PED, 1409.2572,-1042.5371,200.9439)
    tableMP = {}
    for i=0,mpH*mpW do
      tableMP[i] = {0.0,0.0,0.0,1}
    end
    thrMP:run() 
  end  
  
  
function cmd_mpvagon(arg) 
    argH,argW = string.match(arg,"(.+) (.+)")
    if argH ==nil or argW ==nil then 
      return sampAddChatMessage("Используйте:  {ffffff}/mpvagon [длина] [ширина]", 0xffa12e)
    else  
    mpH = argH
        mpW = argW
    tableMP = {}
    for i=0,mpH*mpW do
      tableMP[i] = {0.0,0.0,0.0,1}
    end
      thrMP:run() 
    end
  end  

function cmd_mpvagonSMS(arg) 
    argH = string.match(arg,"(.+)")
    if argH ==nil then
      if tonumber(numberSponsor) ==-1 then return sampAddChatMessage(string.format("Используйте: {ffffff}/vagonSMS [Номер] {A9A9A9}(Номер не определен)"), 0xA9A9A9)
      else return sampAddChatMessage(string.format("Используйте: {ffffff}/vagonSMS [Номер] {A9A9A9}(Номер cпонсора: {ffbf00}%d{A9A9A9})",numberSponsor), 0xA9A9A9) end
    else  
      numberSponsor = argH
      if numberSponsor == "-1" then
        sampAddChatMessage(string.format("Режим отслеживания SMS от спонсора {B22222}отключен ",numberSponsor), 0xA9A9A9)
      else
        sampAddChatMessage(string.format("Включен режим отслеживания SMS. Номер спонсора: {ffbf00}%d", numberSponsor), 0xA9A9A9)
        sampAddChatMessage(string.format("Для отключения отслеживания SMS введите {B22222}/vagonSMS -1",numberSponsor), 0xA9A9A9)
      end
    end
end  
  
function cmdName(arg)
    if #arg == 0 then 
      return sampAddChatMessage("Используйте: {ffffff}/name [id1,id2,...]", 0xFF00FF)
    end
  
    local ids = {}
    for id in string.gmatch(arg, "%d+") do
      table.insert(ids, tonumber(id))
    end
  
    if #ids == 0 then
      return sampAddChatMessage("Некорректный ввод. Используйте: {ffffff}/name [id1,id2,...]", 0xFF00FF)
    end
  
    local nicks = {}
    for _, id in ipairs(ids) do
      local nickss = sampGetPlayerNickname(id)
      if nickss then
        table.insert(nicks, nickss)
      else
        table.insert(nicks, "Неизвестный игрок")
      end
    end
  
    local result = table.concat(nicks, ", ")
    setClipboardText(result)
    sampAddChatMessage("Ники скопированы в буфер обмена: {ffffff}" .. result, 0xFF00FF)
end
  
function mpvagon_function() 
    yX, myY, myZ = getCharCoordinates(PLAYER_PED)
    tempCount = 0
    freezeCharPosition(PLAYER_PED,true)
    for i=0,mpH-1 do
       for j=0,mpW-1 do
    setCharHeading(PLAYER_PED,90.0)
      setCharCoordinates(PLAYER_PED, yX+(17.8*j),myY+(3.5*i),myZ)
          tableMP[tempCount][0] = yX+(17.8*j)
          tableMP[tempCount][1] = myY+(3.5*i) 
          tableMP[tempCount][2] = myZ
          tableMP[tempCount][3] = tempCount+1
       tempCount = tempCount+1  
      wait(1000)
      if tempCount == 30 then wait(5000) end
      sampSendChat("/vec 590")
       end
    end
    All = tempCount
    numerMas = {}
     for i=0,All-1 do
      numerMas[i] = i
    end
    numerMas = shake(numerMas)
    friendsText = ""
    for i=0,All-1 do
        friendsText = string.format("%s %d\n", friendsText, numerMas[i])
    end  
    --sampAddChatMessage(friendsText, 0xffa12e)
    freezeCharPosition(PLAYER_PED,false)
    if regimZag == true then 
      regimZag = fasle 
      setCharCoordinates(PLAYER_PED, 1447.1705,-1048.1598,213.3828)
    end 
    countMP = 0
  end  
  
function cmd_mpvagon1(arg)
      thrMP1:run() 
  end  
  
function mpvagon1_function() 
    if countMP ~= mpH*mpW then
     yX, myY, myZ = getCharCoordinates(PLAYER_PED)
     numI =  numerMas[countMP]
     setCharCoordinates(PLAYER_PED,  tableMP[numI][0],  tableMP[numI][1], tableMP[numI][2])
     wait(500)
     sampSendChat("/respv 4")
     wait(500)
     countMP = countMP+1
     setCharCoordinates(PLAYER_PED,  yX, myY, myZ)
    else
      sampAddChatMessage(string.format("Все вагоны заспавнены (%d/%d)",countMP,mpH*mpW), 0xffa12e)
    end  
  end  
  
  
function sampev.onServerMessage(color, text)
    if numberSponsor ~= -1 then
       numberSponsorTemp = text:match("SMS:%s%w+%s.%sОтправитель:%s.+%[т.(%d+)%]")
       if numberSponsorTemp == nil then numberSponsorTemp = text:match("SMS:%s%w+%s.%sОтправитель:%s.+%[%d+%]%s%[т.(%d+)%]") end
         if tonumber(numberSponsor) == tonumber(numberSponsorTemp) then thrMP1:run()  end
    end
  end
  
function shake(array)
    local counter = #array
    math.randomseed(os.time())
    while counter > 1 do
      local index = math.random(counter)
  
      swap(array, index, counter)   
      counter = counter - 1
    end
    return array
  end
  
function swap(array, index1, index2)
    array[index1], array[index2] = array[index2], array[index1]
  end

function cmdMpNull(arg)
    sponsor = {}
  end
  
function cmdToggleAutoMpJail()
    autoMpJailEnabled = not autoMpJailEnabled
    if autoMpJailEnabled then
        sampAddChatMessage("[MP] Автоматический кик c мп {32CD32}включен", 0xFF00FF)
    else
        sampAddChatMessage("[MP] Автоматический кик с мп {DC143C}выключен", 0xFF00FF)
    end
  end
  
function cmdMpAdd(arg)
    if #arg == 0 or type(tonumber(arg)) ~= 'number' then 
      return sampAddChatMessage("[MP] Используйте: {ffffff}/mpadd [ид]", 0xFF00FF)
    else  
      if sampIsPlayerConnected(arg) then
        name = sampGetPlayerNickname(arg)
        table.insert(sponsor, name)
        sampAddChatMessage(string.format("[HP] Добавлен спонсор %s[%d]", name,arg), 0xFF00FF)
      end  
    end  
  end
  
function cmdBlackAdd(arg)
    if #arg == 0 or type(tonumber(arg)) ~= 'number' then 
        return print('info id no')
    end  

    local playerId = tonumber(arg)
    local playerName = sampGetPlayerNickname(playerId)

    local isSponsor = false
    for i, sponsorName in ipairs(sponsor) do
        if playerName == sponsorName then
            isSponsor = true
            break
        end
    end

    if isSponsor then
        sampAddChatMessage(string.format("[MP] Игрок {FFA500}%s{FFFFFF} является спонсором и не может быть в списке нарушителей.", playerName), 0xFFFFFF)
        return
    end

    if list_length(black) < 9 then
        table.insert(black, arg)
    else
        table.remove(black, 1)
        table.insert(black, arg)
    end  
end
  
  
function cmdDerbi(vehicleId)
    if #vehicleId == 0 or type(tonumber(vehicleId)) ~= 'number' then 
      return sampAddChatMessage("[MP] Используйте: {ffffff}/derbi2 [ид транспорта]", 0xFF00FF)
    else  
      derbiMPCreate:run(tonumber(vehicleId)) 
    end  
  end
  
function derbi_function(vehicleId) 
    for i=1,list_length(derbiCar) do
        setCharHeading(PLAYER_PED,derbiCar[i][4])
        setCharCoordinates(PLAYER_PED, derbiCar[i][1],derbiCar[i][2],derbiCar[i][3])
        wait(1000)
        --sampAddChatMessage(string.format("%d %f %f %f %f", i,derbiCar[i][1],derbiCar[i][2],derbiCar[i][3],derbiCar[i][4]), 0xFF00FF)
        sampSendChat(string.format("/vec %d 171 171 1", vehicleId))
        wait(1000)
        if i == 30 then wait(5000) end
        if i == 60 then wait(5000) end
    end
  end  
  
  
function cmd_getids(arg)
    if #arg == 0 or type(tonumber(arg)) ~= 'number' then 
      return sampAddChatMessage("Используйте: {ffffff}/getids [радиус]", 0xffa12e)
    else  
      if arg == '-1' then
        local dialogTitle = "{ffd700}Регистр игроков"
        local dialogMessage = "Игрок\tВ радиусе\n{FF4500}Выйти\n"
        for i, playerData in ipairs(regisGamer) do
          friendStreamed, friendPed = sampGetCharHandleBySampPlayerId(regisGamer[i][1])
          local playerInfo = string.format("{ffffff}%s[%d]\t{9370DB}Не рядом",regisGamer[i][2],regisGamer[i][1],distanceInteger)
          if friendStreamed then
            playerInfo = string.format("{ffffff}%s[%d]\t{00FF7F}Рядом",regisGamer[i][2],regisGamer[i][1],distanceInteger)
          end
          dialogMessage = dialogMessage .. playerInfo .. "\n"
        end
        return sampShowDialog(1034, dialogTitle, dialogMessage, "Принять", "Отмена",5)
      end
      delFriendN = tonumber(arg)
      friendsText = "ID:{ffffff}"
      tempAll = 0
      tempID = 1
      regisGamer = {}
      for b = 0, 1001 do
        if sampIsPlayerConnected(b) then
          name = sampGetPlayerNickname(b)
          if name ~= nil then regPlayer = string.upper(name) end
          friendStreamed, friendPed = sampGetCharHandleBySampPlayerId(b)
          if friendStreamed then
            friendX, friendY, friendZ = getCharCoordinates(friendPed)
            myX, myY, myZ = getCharCoordinates(playerPed)
            distance = getDistanceBetweenCoords3d(friendX, friendY, friendZ, myX, myY, myZ)
            distanceInteger = math.floor(distance)
          end
          if friendStreamed then 
            if distanceInteger<math.floor(arg) then
              regisGamer[tempID] = {}
              regisGamer[tempID][1] = b
              regisGamer[tempID][2] = name
              tempID = tempID+1
              tempAll = tempAll +1
            end 
          end
        end
      end
      if (tempAll==0) then  friendsText = string.format("ID игроков: {ffffff}В радиусе %d метров нет игроков", tonumber(arg))
      else 
        sampAddChatMessage(string.format("В радиусе %d игроков {ffffff}(/getids -1 для входа в диалог)", tempAll), 0xffa12e)
        local dialogTitle = "{ffd700}Регистр игроков"
        local dialogMessage = "Игрок\tВ радиусе\n{FF4500}Выйти\n"
        for i, playerData in ipairs(regisGamer) do
          friendStreamed, friendPed = sampGetCharHandleBySampPlayerId(regisGamer[i][1])
          local playerInfo = string.format("{ffffff}%s[%d]\t{9370DB}Не рядом",regisGamer[i][2],regisGamer[i][1],distanceInteger)
          if friendStreamed then
            playerInfo = string.format("{ffffff}%s[%d]\t{00FF7F}Рядом",regisGamer[i][2],regisGamer[i][1],distanceInteger)
          end
          dialogMessage = dialogMessage .. playerInfo .. "\n"
        end
        sampShowDialog(1034, dialogTitle, dialogMessage, "Принять", "Отмена",5)
      end
    end  
  end
  
  
function cmd_getmp(arg)

    local args = {}
    for word in arg:gmatch("%S+") do
        table.insert(args, word)
    end

    if #args < 2 or type(tonumber(args[1])) ~= 'number' or type(tonumber(args[2])) ~= 'number' then
        return sampAddChatMessage("[HP] Используйте: {ffffff}/mpskin [ID скина] [радиус]", 0xFF00FF)
    end

    local skinID = tonumber(args[1])
    local radius = tonumber(args[2])

    tableMP = {}
    local tempID = 1
    local tempAll = 0
    local delayCounter = 0
    local thrMP1 = lua_thread.create(function()
        for b = 0, 1001 do
            if sampIsPlayerConnected(b) then
                local name = sampGetPlayerNickname(b)
                if name ~= nil then regPlayer = string.upper(name) end
                local friendStreamed, friendPed = sampGetCharHandleBySampPlayerId(b)
                if friendStreamed then
                    local friendX, friendY, friendZ = getCharCoordinates(friendPed)
                    local myX, myY, myZ = getCharCoordinates(playerPed)
                    local distance = getDistanceBetweenCoords3d(friendX, friendY, friendZ, myX, myY, myZ)
                    local distanceInteger = math.floor(distance)

                    if distanceInteger < radius then
                        tableMP[tempID] = {b, name, sampGetPlayerHealth(b)}
                        tempID = tempID + 1
                        tempAll = tempAll + 1
                        delayCounter = delayCounter + 1

                        sampSendChat(string.format("/skin %d %d", b, skinID))
                        wait (1000)

                        if delayCounter % 7 == 0 then
                            wait(5000)
                        end
                    end
                end
            end
        end

        sampAddChatMessage(string.format("[MP] Скинов выдано {FFFFFF}%d", tempAll), 0xFF00FF)
    end)
end
  
function cmdMouseCoords()
    sampAddChatMessage(string.format("[HP] Настройте панель {fc3000}(ВНИМАНИЕ: ДЛЯ СОХРАНЕНИЯ ИЗМЕНЕНИЙ НУЖНА ПЕРЕЗАГРУЗКА СКРИПТА)", tempAll), 0xFF00FF)
    mouseCoordinates = true
end
  
function cmd_fishbotDev() 
    if developer == true then
       developer = false
       sampAddChatMessage(string.format("[MP] Режим помощника {DC143C}выключен"), 0xFF00FF)
    else
       developer = true
       sampAddChatMessage(string.format("[MP] Режим помощник {32CD32}включен"), 0xFF00FF)
    end
  end    
  
function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    if dialogId == 1034 and string.find(sampGetCurrentServerName(),"Advance RolePlay") then
      
    end    
  end  
  
function sampev.onPlayerChatBubble(playerId, color, distance, duration, message)
    if developer == true then 
        if sampIsPlayerConnected(playerId) then

          local playerName = sampGetPlayerNickname(playerId)

            local isSponsor = false
            for i, sponsorName in ipairs(sponsor) do
                if playerName == sponsorName then
                    isSponsor = true
                    break
                end
            end

            if isSponsor then
                return
            end

            if checks.checkHealth.v and (message == '+60 Hp') then 
                sampAddChatMessage(string.format("[HP] Использовал аптечку %s[%d]", sampGetPlayerNickname(playerId), playerId), 0xFF00FF) 
                cmdBlackAdd(string.format("%d", playerId))
                if autoMpJailEnabled then
                  lua_thread.create(function()
                      wait(2000)
                    if sampIsPlayerConnected(playerId) then
                          sampSendChat(string.format("/jail %d 20 Использовал аптечку", playerId))
                          wait(1000)
                          sampSendChat(string.format("/unjail %d", playerId))
                          sampAddChatMessage(string.format("[MP] Игрок %s[%d] был автоматически исключен с мероприятия", playerName, playerId), 0xFF00FF)
                      else
                          sampAddChatMessage(string.format("[MP] Игрок %s[%d] не подключен к серверу.", playerName, playerId), 0xFF0000)
                      end
                  end)              
                end
            end
          end
            if checks.checkRepair.v and (message == 'Отремонтировал транспорт') then 
                sampAddChatMessage(string.format("[HP] Отремонтировал транспорт %s[%d]", sampGetPlayerNickname(playerId), playerId), 0xFF00FF)
                cmdBlackAdd(string.format("%d", playerId))
                if autoMpJailEnabled then
                  lua_thread.create(function()
                      wait(2000)
                    if sampIsPlayerConnected(playerId) then
                          sampSendChat(string.format("/jail %d 20 Использовал /fix", playerId))
                          wait(1000)
                          sampSendChat(string.format("/unjail %d", playerId))
                          sampAddChatMessage(string.format("[MP] Игрок %s[%d] был автоматически исключен с мероприятия", playerName, playerId), 0xFF00FF)
                      else
                          sampAddChatMessage(string.format("[MP] Игрок %s[%d] не подключен к серверу.", playerName, playerId), 0xFF0000)
                      end
                  end)              
                end
        end
    end
  end
  
function sampev.onShowDialog(dialogId, style, title, button1, button2, text)
    --sampAddChatMessage(string.format("id %d", dialogId), 0xffffff)
  end  
  
function sampev.onApplyPlayerAnimation( playerId, animLib, animName, frameDelta, loop, lockX, lockY, freeze, time )
   -- sampAddChatMessage(string.format("id playerId %d установил %s", playerId,animLib), 0xffffff)
  end
  
function sampev.onSetPlayerAttachedObject(playerId,index,create,object)
    --sampAddChatMessage(string.format("id playerId %d установил %d[%d]", playerId,object.modelId,index), 0xffffff)
  end
  
function sampev.onSetPlayerSpecialAction(playerId)
    --sampAddChatMessage(string.format("sp anim id %d",playerId), 0xffffff)
  end
  
function sampev.onClearPlayerAnimation(playerId)
    --sampAddChatMessage(string.format("sp games id %d", playerId), 0xffffff)
end
  
function cmd_intaSMI_exit() 
    setCharCoordinates(PLAYER_PED, 1660.3853,-1679.6868,21.4306)
    sampSendChat("/setvw 0")
    sampSendChat("/setint 0")
end

function thread_function() 
    setCharCoordinates(PLAYER_PED, 1749.7640,-27.1696,997.0104)
    freezeCharPosition(PLAYER_PED,true)
    sampSendChat("/setvw 11002")
    sampSendChat("/setint 1")
    wait(2000)
    setCharCoordinates(PLAYER_PED, 1749.7640,-27.1696,997.0104)
    wait(1000)
    freezeCharPosition(PLAYER_PED, false)
    setCharCoordinates(PLAYER_PED, 2365.0513,-1135.5017,1050.8826)
    sampSendChat("/setvw 229")
  end  
  
function list_length( t )
   
      local len = 0
      for _,_ in pairs( t ) do
          len = len + 1
      end
   
      return len
  end
  
  function sampev.onPlayerExitVehicle(playerId, vehicleId)
    if developer == true then
        local playerName = sampGetPlayerNickname(playerId)

        local isSponsor = false
        for i, sponsorName in ipairs(sponsor) do
            if playerName == sponsorName then
                isSponsor = true
                break
            end
        end
        if isSponsor then return end

        if checks.checkExitVehicle.v then
            sampAddChatMessage(string.format("[MP] Игрок %s[%d] покинул транспортное средство.", playerName, playerId), 0xFF00FF)

            if autoMpJailEnabled then
                lua_thread.create(function()
                    wait(2000)
                    if sampIsPlayerConnected(playerId) then
                        sampSendChat(string.format("/jail %d 20 Покинул транспорт", playerId))
                        wait(1000)
                        sampSendChat(string.format("/unjail %d", playerId))
                        sampAddChatMessage(
                            string.format("[MP] Игрок %s[%d] был автоматически исключен с мероприятия", 
                            playerName, 
                            playerId), 
                        0xFF00FF)
                    else
                        sampAddChatMessage(
                            string.format("[MP] Игрок %s[%d] не подключен к серверу.", 
                            playerName, 
                            playerId), 
                        0xFF0000)
                    end
                end)
            end
        end
    end
end

  
function removeElementByIndex(array, index)
    local newArray = {}
  
    for i = 1, #array do
        if i ~= index then
            table.insert(newArray, array[i])
        end
    end
  
    return newArray
end
  
  
  
function LIP.load(fileName)
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.');
    local file = assert(io.open(fileName, 'r'), 'Error loading file : ' .. fileName);
    local data = {};
    local section;
    for line in file:lines() do
      local tempSection = line:match('^%[([^%[%]]+)%]$');
      if(tempSection)then
        section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
        data[section] = data[section] or {};
      end
      local param, value = line:match('^([%w|_]+)%s-=%s-(.+)$');
      if(param and value ~= nil)then
        if(tonumber(value))then
          value = tonumber(value);
        elseif(value == 'true')then
          value = true;
        elseif(value == 'false')then
          value = false;
        end
        if(tonumber(param))then
          param = tonumber(param);
        end
        data[section][param] = value;
      end
    end
    file:close();
    return data;
  end
  
function LIP.save(fileName, data)
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.');
    assert(type(data) == 'table', 'Parameter "data" must be a table.');
    local file = assert(io.open(fileName, 'w+b'), 'Error loading file :' .. fileName);
    local contents = '';
    for section, param in pairs(data) do
      contents = contents .. ('[%s]\n'):format(section);
      for key, value in pairs(param) do
        contents = contents .. ('%s=%s\n'):format(key, tostring(value));
      end
      contents = contents .. '\n';
    end
    file:write(contents);
    file:close();
end

function cmd_mgunset(arg)
  local args = {}
  for word in arg:gmatch("%S+") do
      table.insert(args, word)
  end

  if #args < 3 then
      return sampAddChatMessage("Используйте: /mgunset [ID игроков через пробел] [ID оружия] [Количество повторений]", 0xFF0000)
  end

  local player_ids = table.concat(args, " ", 1, #args - 2)
  local weapon_ids = args[#args - 1]
  local repeat_count = tonumber(args[#args])

  local weapon_id_num = tonumber(weapon_ids)
  if not weapon_id_num or weapon_id_num < 22 or weapon_id_num > 34 then
      return sampAddChatMessage(string.format("Ошибка: ID оружия %s вне допустимого диапазона (22-34).", weapon_ids), 0xFF0000)
  end

  if not repeat_count or repeat_count < 1 then
      return sampAddChatMessage("Ошибка: количество повторений должно быть числом больше 0.", 0xFF0000)
  end

  if repeat_count > 10 then
      return sampAddChatMessage("Ошибка: количество повторений не должно превышать 10.", 0xFF0000)
  end

  cfg.mgun.player_ids = player_ids
  cfg.mgun.weapon_ids = weapon_ids
  cfg.mgun.repeat_count = repeat_count
  inicfg.save(cfg, configPath)

  sampAddChatMessage("[MGUN] Данные сохранены!", 0x00FF00)
  sampAddChatMessage(string.format("Игроки: %s, Оружие: %s, Повторений: %d", cfg.mgun.player_ids, cfg.mgun.weapon_ids, cfg.mgun.repeat_count), 0x00FF00)
end



function cmd_mgun()
  local players = {}
  for id in cfg.mgun.player_ids:gmatch("%S+") do
      table.insert(players, tonumber(id))
  end

  local weapons = {}
  for id in cfg.mgun.weapon_ids:gmatch("%S+") do
      table.insert(weapons, tonumber(id))
  end

  if #players == 0 or #weapons == 0 then
      return sampAddChatMessage("[MGUN] Ошибка: данные не настроены. Используйте /mgunset.", 0xFF0000)
  end

  lua_thread.create(function()
    local total_give_count = 0

    for i = 1, cfg.mgun.repeat_count do
        for _, player_id in ipairs(players) do
            for _, weapon_id in ipairs(weapons) do
                sampSendChat(string.format("/givegun %d %d 100", player_id, weapon_id))
                total_give_count = total_give_count + 1

                if total_give_count % 6 == 0 then
                    wait(5000)
                else
                    wait(900)
                end
            end
        end
    end

    sampAddChatMessage("[MGUN] Оружие успешно выдано!", 0x00FF00)
  end)
end

local notifiedDrugsPlayers = {}

function checkPlayersAnimationsInRadius()
  local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
  local myID = sampGetPlayerIdByCharHandle(PLAYER_PED)

  for playerId = 0, 1000 do
      if sampIsPlayerConnected(playerId) and playerId ~= myID then
          local streamed, playerHandle = sampGetCharHandleBySampPlayerId(playerId)
          if streamed and doesCharExist(playerHandle) then
              local x, y, z = getCharCoordinates(playerHandle)
              local dist = getDistanceBetweenCoords3d(myX, myY, myZ, x, y, z)
              if dist <= checkRadius then
                  local animId = sampGetPlayerAnimationId(playerId)
                  local playerName = sampGetPlayerNickname(playerId)

                  local isSponsor = false
                  for _, sName in ipairs(sponsor) do
                      if playerName == sName then
                          isSponsor = true
                          break
                      end
                  end
                  if isSponsor then goto continue_anim end

                  local isTargetAnim = false
                  for _, tId in ipairs(targetAnimId) do
                      if animId == tId then
                          isTargetAnim = true
                          break
                      end
                  end

                  if isTargetAnim then
                      if not notifiedPlayers[playerId] then
                          sampAddChatMessage(string.format("[MP] Возможно использует анимацию %s[%d]", playerName, playerId), 0xFF00FF)
                          notifiedPlayers[playerId] = true
                          cmdBlackAdd(tostring(playerId))

                          if autoMpJailEnabled then
                              lua_thread.create(function()
                                  wait(2000)
                                  if sampIsPlayerConnected(playerId) then
                                      sampSendChat(string.format("/jail %d 20 Запрещенная анимация", playerId))
                                      wait(1000)
                                      sampSendChat(string.format("/unjail %d", playerId))
                                      sampAddChatMessage(string.format("[MP] Игрок %s[%d] исключен", playerName, playerId), 0xFF00FF)
                                  else
                                      sampAddChatMessage(string.format("[MP] Игрок %s[%d] не в игре.", playerName, playerId), 0xFF0000)
                                  end
                              end)
                          end
                      end
                  else
                      if notifiedPlayers[playerId] and playerAnimations[playerId] == animId then
                          notifiedPlayers[playerId] = nil
                      end
                  end

                  playerAnimations[playerId] = animId
              else
                  notifiedPlayers[playerId] = nil
                  playerAnimations[playerId] = nil
              end
          end
      end
      ::continue_anim::
  end
end

function checkPlayersDrugsInRadius()
  local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
  local myID = sampGetPlayerIdByCharHandle(PLAYER_PED)

  for playerId = 0, 1000 do
      if sampIsPlayerConnected(playerId) and playerId ~= myID then
          local streamed, playerHandle = sampGetCharHandleBySampPlayerId(playerId)
          if streamed and doesCharExist(playerHandle) then
              local x, y, z = getCharCoordinates(playerHandle)
              local dist = getDistanceBetweenCoords3d(myX, myY, myZ, x, y, z)
              if dist <= checkRadius then
                  local specialAction = sampGetPlayerSpecialAction(playerId)
                  local playerName = sampGetPlayerNickname(playerId)

                  local isSponsor = false
                  for _, sName in ipairs(sponsor) do
                      if playerName == sName then
                          isSponsor = true
                          break
                      end
                  end
                  if isSponsor then goto continue_drugs end

                  if specialAction == 21 then
                      if not notifiedDrugsPlayers[playerId] then
                          sampAddChatMessage(string.format("[MP] %s[%d] использует наркотики.", playerName, playerId), 0xFF00FF)
                          notifiedDrugsPlayers[playerId] = true
                          cmdBlackAdd(tostring(playerId))

                          if autoMpJailEnabled then
                              lua_thread.create(function()
                                  wait(2000)
                                  if sampIsPlayerConnected(playerId) then
                                      sampSendChat(string.format("/jail %d 20 Использовал наркотики", playerId))
                                      wait(1000)
                                      sampSendChat(string.format("/unjail %d", playerId))
                                      sampAddChatMessage(string.format("[MP] Игрок %s[%d] исключен", playerName, playerId), 0xFF00FF)
                                  else
                                      sampAddChatMessage(string.format("[MP] Игрок %s[%d] не в игре.", playerName, playerId), 0xFF0000)
                                  end
                              end)
                          end
                      end
                  else
                      if notifiedDrugsPlayers[playerId] then
                          notifiedDrugsPlayers[playerId] = nil
                      end
                  end
              else
                  notifiedDrugsPlayers[playerId] = nil
              end
          end
      end
      ::continue_drugs::
  end
end

function sampev.onPlayerJoin(id, clist, isNPC, nick)
  if not isNPC then
      for i, sponsorName in ipairs(sponsor) do
          if nick == sponsorName then
              sponsorStatus[sponsorName] = true
              sampAddChatMessage(string.format("[MP] Спонсор {FFA500}%s{FF0000} зашел в игру.", nick), 0xFF0000)
              break
          end
      end
  end
end

function sampev.onPlayerQuit(id, reason)
  local playerName = sampGetPlayerNickname(id)
      for i, sponsorName in ipairs(sponsor) do
          if sponsorName == playerName then
              sponsorStatus[sponsorName] = false
              sampAddChatMessage(string.format("[MP] Спонсор {FFA500}%s{FF0000} покинул игру.", sponsorName), 0xFF0000)
              break
          end
      end
end

function cmd_mpremove(arg)
  if #arg == 0 or type(tonumber(arg)) ~= 'number' then 
      return sampAddChatMessage("Используйте: {ffffff}/mpremove [id]", 0xFF00FF)
  end

  local playerId = tonumber(arg)
  local playerName = sampGetPlayerNickname(playerId)

  for i, sponsorName in ipairs(sponsor) do
      if sponsorName == playerName then
          table.remove(sponsor, i)
          sampAddChatMessage(string.format("[MP] Спонсор {FFA500}%s{FFFFFF} удален из списка.", playerName), 0xFF00FF)
          return
      end
  end

  sampAddChatMessage("Спонсор не найден.", 0xFF0000)
end

function checkPlayersHealthInRadius()
  local myX, myY, myZ = getCharCoordinates(PLAYER_PED)
  local myId = sampGetPlayerIdByCharHandle(PLAYER_PED)

  for playerId = 0, 1000 do
      if sampIsPlayerConnected(playerId) and playerId ~= myId then
          local streamed, playerHandle = sampGetCharHandleBySampPlayerId(playerId)
          if streamed and doesCharExist(playerHandle) then
              local playerX, playerY, playerZ = getCharCoordinates(playerHandle)
              local distance = getDistanceBetweenCoords3d(myX, myY, myZ, playerX, playerY, playerZ)

              local isSponsor = false
                  for _, sName in ipairs(sponsor) do
                      if playerName == sName then
                          isSponsor = true
                          break
                      end
                  end
                  if isSponsor then goto continue_health end

              if distance <= checkRadius then
                  local playerName = sampGetPlayerNickname(playerId)
                  local currentHealth = sampGetPlayerHealth(playerId)

                  local isSponsor = false
                  for _, sponsorName in ipairs(sponsor) do
                      if playerName == sponsorName then
                          isSponsor = true
                          break
                      end
                  end

                  if not isSponsor then
                      if playerHealth[playerId] then
                          local previousHealth = playerHealth[playerId]
                          if currentHealth < previousHealth then
                              if not notifiedPlayers[playerId] then
                                  sampAddChatMessage(string.format("[HP] У игрока %s[%d] уменьшилось HP: %.1f -> %.1f", 
                                      playerName, playerId, previousHealth, currentHealth), 0xFF0000)
                                  notifiedPlayers[playerId] = true
                              end
                          elseif currentHealth > previousHealth then
                              notifiedPlayers[playerId] = nil 
                          end
                      end
                      playerHealth[playerId] = currentHealth
                  end
              else
                  playerHealth[playerId] = nil
                  notifiedPlayers[playerId] = nil
              end
          end
      end
      ::continue_health::
  end
end

function cmd_mphelp()
  local dialogTitle = "{FFCD00}IVENT TOOLS - Список команд"
  local dialogMessage =
      "                                           {FFFFFF}Список доступных команд и их описание:\n\n" ..
      "{FFA12E}/mphelp{FFFFFF} — Показать этот список команд.\n\n" ..
      "{FFA12E}/vagon{FFFFFF} — Описание игры Вагоны.\n\n" ..
      "{FFA12E}/mgun{FFFFFF} — Открыть меню настройки и выдачи оружия.\n" ..
      "{FFA12E}/mgunset [ID игроков] [ID оружия] [Количество повторений выдачи]{FFFFFF} — Настроить выдачу оружия.\n" ..
      "{FFA12E}/mguns{FFFFFF} — Выдать оружие согласно настройкам.\n\n" ..
      "{FFA12E}/getids [радиус]{FFFFFF} — Показать игроков в указанном радиусе.\n" ..
      "{FFA12E}/tpint{FFFFFF} — Телепортироваться в выбранный интерьер.\n" ..
      "{FFA12E}/autojail{FFFFFF} — Включить/выключить автоматический кик с мероприятия.\n" ..
      "{FFA12E}/mpskin [ID скина] [радиус]{FFFFFF} — Выдать скин игрокам в радиусе.\n\n" ..
      "{FFA12E}/derbi2 [ID транспорта]{FFFFFF} — Заспавнить машины с указанным транспортом.\n" ..
      "{FFA12E}/sthp{FFFFFF} — Включить/выключить режим помощника в проведении МП.\n" ..
      "{FFA12E}/sthpmenu{FFFFFF} — Настройка режима помощник в проведении МП (/sthp).\n\n" ..
      "{FFA12E}/mpmove{FFFFFF} — Настроить позицию панели спонсоры/нарушители.\n" ..
      "{FFA12E}/mpadd [ID]{FFFFFF} — Добавить спонсора в список.\n" ..
      "{FFA12E}/mpnull{FFFFFF} — Полностью очистить список спонсоров.\n" ..
      "{FFA12E}/mpremove [ID]{FFFFFF} — Удалить спонсора из списка.\n\n" ..
      "{FFA12E}/name [ID1,ID2,...]{FFFFFF} — Скопировать ники игроков в буфер обмена.\n\n"

  sampShowDialog(1000, dialogTitle, dialogMessage, "Закрыть", "")
end

return LIP;
