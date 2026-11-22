enum LegalDocumentType { privacy, terms }

class LegalSection {
  final String heading;
  final List<String> paragraphs;

  const LegalSection({required this.heading, required this.paragraphs});
}

class LegalDocument {
  final String title;
  final String updatedAt;
  final String summary;
  final List<LegalSection> sections;

  const LegalDocument({
    required this.title,
    required this.updatedAt,
    required this.summary,
    required this.sections,
  });
}

const privacyPolicyDocument = LegalDocument(
  title: '隐私声明',
  updatedAt: '2026-11-23',
  summary: 'GDOU 助手不设立用户数据库，不采集广告或行为追踪数据；你的账号凭据与教务缓存仅保存在当前设备本地。',
  sections: [
    LegalSection(
      heading: '一、信息处理范围与用途',
      paragraphs: [
        '当你主动登录广东海洋大学教务系统时，应用会处理你输入的学号、统一身份认证密码、图形验证码或二次验证动态码，仅用于完成教务登录并查询本人的课表、校历、成绩、成绩分项明细与考试日程。',
        '在登录过程中生成的教务会话 Cookie 与设备指纹仅用于维持登录态及减少同一设备的重复二次验证。',
      ],
    ),
    LegalSection(
      heading: '二、本地存储与缓存管理',
      paragraphs: [
        '本应用的配套查询服务采用无数据库架构，不会在服务端持久化存储你的账号、密码、Cookie 或任何教务查询结果。',
        '若你勾选「记住密码」，学号与密码将通过系统安全存储加密保存在当前设备本地，用于会话过期时的静默重登；取消勾选或退出登录后将清除已保存的密码。',
        '课表、校历、成绩、成绩分项明细与考试日程默认保存在设备本地缓存中以支持离线查看，不会自动过期删除。你可随时通过「设置 → 刷新缓存」、退出登录或卸载应用主动清除本地数据。',
      ],
    ),
    LegalSection(
      heading: '三、网络通信与外部服务',
      paragraphs: [
        '应用仅在你执行登录、查询或刷新操作时向配置的教务查询接口发送必要请求；当你点击「检查更新」时，应用会请求 GitHub Releases 接口以获取最新版本号与发布说明。',
        '本应用未接入任何第三方广告、商业统计分析或用户画像 SDK，也不会向无关第三方出售、出租或共享你的个人信息。',
      ],
    ),
    LegalSection(
      heading: '四、系统权限说明',
      paragraphs: [
        '网络权限：用于连接教务查询接口及检查应用版本更新。',
        '通知、闹钟与开机启动权限：仅用于在你开启「上课提醒」或「考试提醒」时在设备本地按时发送提醒，并在设备重启后恢复已安排的本地提醒。你可随时在应用设置或系统设置中关闭相关权限。',
      ],
    ),
    LegalSection(
      heading: '五、开源透明与反馈',
      paragraphs: [
        '本应用为开源项目，你可以随时查阅源代码以核验数据处理方式。如对本隐私声明有疑问或建议，可通过项目 GitHub 仓库提交 Issue 反馈。',
      ],
    ),
  ],
);

const userAgreementDocument = LegalDocument(
  title: '用户协议',
  updatedAt: '2026-11-23',
  summary: '使用 GDOU 助手即表示你理解本应用为非官方开源学习工具，所有教务信息均以学校官方系统与通知为准。',
  sections: [
    LegalSection(
      heading: '一、服务性质与声明',
      paragraphs: [
        'GDOU 助手是一款面向个人学习与日常查询的开源第三方工具，与广东海洋大学官方无隶属、合作或授权关系。',
        '应用展示的课表、教学周、成绩、成绩分项明细与考试日程均来自学校教务系统。因网络波动、系统维护、本地缓存滞后或上游页面结构调整，展示内容可能存在延迟或偏差，最终信息请以广东海洋大学教务系统及各学院官方通知为准。',
      ],
    ),
    LegalSection(
      heading: '二、合规使用规范',
      paragraphs: [
        '你仅可使用本应用登录和查询本人合法持有的教务账号信息，不得冒用他人账号，也不得利用本应用进行高频并发请求、批量抓取或其他影响学校系统正常运行的行为。',
        '请妥善保管你的设备、统一身份认证密码及二次验证码，切勿将账号凭据或会话信息泄露给他人。',
      ],
    ),
    LegalSection(
      heading: '三、提醒功能与免责提示',
      paragraphs: [
        '上课提醒与考试提醒基于本地通知与系统闹钟机制实现，可能受操作系统省电策略、后台限制、权限关闭或教务临时调课影响而出现延迟或未触发，请勿将本应用作为出席课程或参加考试的唯一依据。',
        '本应用按「现状」免费提供，开发者不对服务的持续可用性、绝对准确性或特定用途适用性作明示或默示担保，也不对因使用或无法使用本应用引起的任何直接或间接损失承担责任。',
      ],
    ),
    LegalSection(
      heading: '四、协议更新与终止',
      paragraphs: [
        '随着功能迭代或上游教务系统变化，开发者可能会修订本用户协议并在应用更新中同步生效。如你不同意修订后的内容，可停止使用并卸载本应用。',
      ],
    ),
  ],
);

LegalDocument getLegalDocument(LegalDocumentType type) => switch (type) {
  LegalDocumentType.privacy => privacyPolicyDocument,
  LegalDocumentType.terms => userAgreementDocument,
};
