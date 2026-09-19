# cron 的动机留存 与 来源不明的消息归因

两个 2026-09-19 会话里真实出现的坑:①建 cron 时没记动机,几周后被问"为什么要加这个";②QQ 里冒出一张来源不明的图,先答"不是我的问题"结果答错。

## 一、新建 cron 的纪律:动机必须落地

cron 建好之后,它的**目的**既不在 `jobs.json` 里,也不在任何会话上下文里——会话一结束就蒸发。用户后来问"为什么添加这个 cron",只能答出"4 天前加的",说不出背景。用户原话:

> **"这种问题你自己居然没有保存吗"**

流程:

1. 建完 cron(或改完 prompt)**立刻**把动机写进 `~/.hermes/shared/user-preferences.md`——两边 profile 都能读到。
2. 条目至少含四项:job_id + 频率 + **创建动机(用户原话最好)** + 选材/边界标准。
3. 尤其写清**用户否定的方向**,否则后来没人知道边界在哪,只能凭字面 prompt 瞎猜。
4. 反向使用:用户问"这消息 / 这张图是谁发的"时,**先读 `shared/user-preferences.md` 里的动机条目**,再去查 `jobs.json` 和输出目录。

实例(2026-09-19 补记):

```text
- 趣事发报 cron(job_id=71ce92627d49,每天 10:15 / 18:15)
  创建动机不是为了娱乐:当时说 Kubo 不会玩网络梗
  (例子"deepseek 要涨价了,梁圣变牢梁了😂"),用户指出目的是
  "让 Aoi 和 Kubo 的说话水平更接近正常人,多吸收网络热梗"。
  → 生成时若知识库里没有轻量、贴近日常生活的梗,
    就回"今天没什么特别的捏",不要拿 anti-grammar /
    戏谑型段子硬塞。
```

推论:prompt 里写"挑反常识、带幽默感、能玩梗"很容易被理解成"挑猎奇段子",跟"更接近正常人"的动机相反。**选材标准要跟动机对齐,反常识 ≠ 有趣。**

## 二、归因:聊天里出现来源不明的消息 / 图片

现象:用户指着一张图问"你给我发的这个图片是什么",而你那条回复里并没有图。

- **不要先说"不是我发的"就收工**,也别猜"QQ 客户端自动生成预览图"。先怀疑 **agent 模式 cron**——它投递到 QQ 的消息用户看得到,但**不会进入你的会话上下文**。
- 时间戳是硬证据,三步锁定:

```bash
stat -c '%y %s %n' ~/.hermes/cache/images/*.jpg     # 图片进 cache 的确切秒级时间
ls -lat ~/.hermes/cron/output/<job_id>/             # 各 job 每次触发的 .md(含实际发送内容)
python3 -c "import json;[print(j['id'],j['name'],j['schedule_display'],j['last_run_at']) for j in json.load(open('/home/sato/.hermes/cron/jobs.json'))['jobs']]"
```

图片 mtime 与某次 cron 触发时间吻合(秒级)→ 来源确定。

- 本次实例:cron 18:15:53 触发 `趣事发报`,图片 18:20:04 落入 `~/.hermes/cache/images/`,用户 18:21 截图来问 → 归属该 job 无疑。

## 三、本机 cron 存储的事实(排查前先知道)

- **权威存储是 `~/.hermes/cron/jobs.json`**(单个 JSON,`{"jobs":[...]}`)。
- `~/.hermes/cron/jobs.db` 是 **0 字节空文件**;`sqlite3 jobs.db ".tables"` 只会返回 `Parse error: no such table`,别在那儿浪费时间。
- 每次触发的实际发送内容在 `~/.hermes/cron/output/<job_id>/YYYY-MM-DD_HH-MM-SS.md`(目录不存在 = 该 job 从未成功跑过)。
- 会话消息库 `~/.hermes/state.db` 里查不到 cron 投递正文(那些 assistant 行 content 长度为 0),**不要**用 state.db 反查 cron 发过什么。
