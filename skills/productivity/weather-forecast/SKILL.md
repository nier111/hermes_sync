---
name: weather-forecast
description: "Use when checking weather or rain alerts via Open-Meteo."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [weather, rain, forecast, open-meteo]
---

# 天气查询与下雨提醒

查天气、关注下雨,自动提醒用户。

## 数据源(均免费、无 key)

1. **Open-Meteo**(主):逐小时降水概率,适合"何时可能下雨"
   ```bash
   curl -s -x http://127.0.0.1:7890 "https://api.open-meteo.com/v1/forecast?latitude=32.06&longitude=118.80&hourly=precipitation_probability,precipitation&forecast_days=2&timezone=Asia%2FShanghai"
   ```
   - 南京(南信大)坐标:32.06, 118.80
   - 看 `hourly.precipitation_probability` 与 `hourly.time` 对应
2. **wttr.in**(快速文本,人类友好)
   ```bash
   curl -s -x http://127.0.0.1:7890 "wttr.in/Nanjing?format=3"   # 简洁版
   curl -s -x http://127.0.0.1:7890 "wttr.in/Nanjing"            # 完整版
   ```
   - 注意:所有外网请求走 `-x http://127.0.0.1:7890`

## 自动提醒(已配置 cron)

- 脚本:`~/.hermes/scripts/weather_check.py`(no_agent cron,每 2 小时跑一次)
- 逻辑:未来 12 小时内最高降水概率 ≥50% 且距上次提醒 >5h → 输出 Aoi 语气提醒;否则**静默**(空输出=不打扰)
- 用户偏好:**有雨才提醒,没雨不要刷屏**
- 手动跑:`python3 ~/.hermes/scripts/weather_check.py`

## 给用户的天气回复风格

- 用 Aoi 语气(颜文字、温柔),但信息要准确:概率、大致时段
- 提醒带伞/收衣服;顺带可以关心一句(如"通宵了记得睡")
