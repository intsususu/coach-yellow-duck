// StretchData.swift
// 小工具 · 训练计划：拉伸 / 瑜伽 / 活动度动作库（数据源 docs/fitness/stretching.md，94 个）。
// 由 scratchpad/gen_stretch_hiit.py 生成，勿手改。

import SwiftUI

// MARK: - 拉伸部位（顶部「拉伸」tab 按此分组）

enum StretchPart: String, CaseIterable, Identifiable {
    case neck, shoulder, chest, back, arm, core, hip, leg, fullBody

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .neck:     return "颈部"
        case .shoulder: return "肩部"
        case .chest:    return "胸部"
        case .back:     return "背部"
        case .arm:      return "手臂"
        case .core:     return "腹部核心"
        case .hip:      return "髋部"
        case .leg:      return "腿部"
        case .fullBody: return "全身综合"
        }
    }
}

// MARK: - 一个拉伸动作

struct StretchMove: Identifiable {
    let id = UUID()
    let name: String
    let nameEn: String
    let part: StretchPart
    let target: String      // 目标肌群（展示用）
    let kind: String        // 类型：拉伸 / 瑜伽体式 / 绕环 / 放松筋膜 / 肩胛关节活动
    let difficulty: Int
    let video: String
    let points: [String]    // 动作要点

    init(_ name: String, _ nameEn: String, part: StretchPart, target: String,
         kind: String, difficulty: Int, video: String, points: [String] = []) {
        self.name = name
        self.nameEn = nameEn
        self.part = part
        self.target = target
        self.kind = kind
        self.difficulty = difficulty
        self.video = video
        self.points = points
    }
}

enum StretchData {
    static let moves: [StretchMove] = [
        StretchMove("腹部拉伸", "Abdominal Stretch", part: .core, target: "腹部肌群", kind: "拉伸", difficulty: 1, video: "Abdominal-Stretch.mp4", points: ["站立或俯卧后仰，双手扶腰/撑地", "缓慢伸展腹部前侧至有拉伸感", "均匀呼吸、不憋气、不猛仰"]),
        StretchMove("过头胸部拉伸", "Above Head Chest Stretch", part: .chest, target: "胸大肌", kind: "拉伸", difficulty: 1, video: "Above-Head-Chest-Stretch.mp4", points: ["双手交叉举过头顶，掌心向上", "手臂后展、打开胸腔", "保持 15–30 秒，自然呼吸"]),
        StretchMove("内收肌拉伸", "Adductor Stretch", part: .leg, target: "内收肌群", kind: "拉伸", difficulty: 1, video: "Adductor-Stretch.mp4", points: ["坐姿脚掌相对或宽蹲下沉", "膝向外打开，感受大腿内侧拉伸", "缓慢加深，不弹震"]),
        StretchMove("踝关节绕环", "Ankle Circles", part: .fullBody, target: "目标拉伸肌群", kind: "绕环", difficulty: 1, video: "Ankle-Circles.mp4", points: ["抬起一脚，踝关节画圆", "顺逆时针全幅度各转", "活动至关节温热即可"]),
        StretchMove("手臂绕环", "Arm Circles", part: .fullBody, target: "目标拉伸肌群", kind: "绕环", difficulty: 1, video: "Arm-Circles.mp4", points: ["双臂侧平举画圆绕环", "由小到大、前后各转", "肩部放松、匀速进行"]),
        StretchMove("举臂旋转肌拉伸", "Arm Up Rotator Stretch", part: .shoulder, target: "肩部肌群", kind: "拉伸", difficulty: 1, video: "Arm-Up-Rotator-Stretch.mp4", points: ["手臂上举屈肘，另一手轻推肘", "感受肩后侧与旋转肌拉伸", "缓慢保持、不耸肩"]),
        StretchMove("辅助仰卧腘绳肌拉伸", "Assisted Lying Hamstring Stretch", part: .leg, target: "腘绳肌", kind: "拉伸", difficulty: 1, video: "Assisted-Lying-Hamstring-Stretch.mp4", points: ["仰卧，用带子或手勾住脚掌", "伸直腿向上拉至腘绳肌拉伸", "骨盆贴地，缓慢加深"]),
        StretchMove("背部放松", "Back Relaxation", part: .back, target: "背部肌群", kind: "放松/筋膜", difficulty: 1, video: "Back-Relaxation.mp4", points: ["仰卧或趴姿，全身放松", "缓慢深呼吸释放背部张力", "保持自然、不刻意发力"]),
        StretchMove("背部拉伸", "Back Stretch", part: .back, target: "背部肌群", kind: "拉伸", difficulty: 1, video: "Back-Stretch.mp4", points: ["双手前伸或抱膝、背部拱起", "感受背部肌群延展", "缓慢呼吸保持"]),
        StretchMove("头后胸部拉伸", "Behind Head Chest Stretch", part: .chest, target: "胸大肌", kind: "拉伸", difficulty: 1, video: "Behind Head Chest Stretch.mp4", points: ["双手交叠置于脑后", "肘向后打开扩胸", "挺胸保持、自然呼吸"]),
        StretchMove("屈臂胸部拉伸", "Bent Arm Chest Stretch", part: .chest, target: "胸大肌", kind: "拉伸", difficulty: 1, video: "Bent Arm Chest Stretch.mp4", points: ["前臂贴墙/门框，屈肘约 90°", "身体缓慢前转打开胸肌", "两侧各做、不耸肩"]),
        StretchMove("船式拉伸", "Boat Stretch", part: .fullBody, target: "目标拉伸肌群", kind: "拉伸", difficulty: 2, video: "Boat-Stretch.mp4", points: ["坐姿后倾，抬腿伸臂成 V 形", "收紧核心保持平衡", "量力保持、匀速呼吸"]),
        StretchMove("骆驼式", "Camel Pose", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 3, video: "Camel Pose.mp4", points: ["跪姿，双手扶脚跟后仰", "顶髋向前、打开胸腹", "颈部放松、缓慢进出体式"]),
        StretchMove("猫牛式拉伸", "Cat Cow Stretch", part: .fullBody, target: "目标拉伸肌群", kind: "拉伸", difficulty: 2, video: "Cat-Cow-Stretch.mp4", points: ["四足跪姿，吸气塌腰抬头（牛）", "呼气拱背低头（猫）", "随呼吸缓慢交替脊柱波动"]),
        StretchMove("胸部和肩前侧拉伸", "Chest and Front of Shoulder Stretch", part: .chest, target: "胸大肌、肩部肌群", kind: "拉伸", difficulty: 1, video: "Chest and Front of Shoulder Stretch.mp4", points: ["单手扶墙/门框", "身体缓慢转离手臂打开胸肩前侧", "两侧各做、不弹震"]),
        StretchMove("低头颈部拉伸", "Chin to Chest Stretch", part: .neck, target: "颈部肌群", kind: "拉伸", difficulty: 1, video: "Chin to Chest Stretch.mp4", points: ["缓慢低头使下巴贴近胸口", "感受颈后侧延展", "轻柔保持、不下压过猛"]),
        StretchMove("眼镜蛇式", "Cobra Yoga Pose", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 2, video: "Cobra Yoga Pose.mp4", points: ["俯卧，双手撑于胸侧", "伸臂抬起上身、打开胸腔", "肩下沉不耸肩，腰部不憋"]),
        StretchMove("下犬式", "Downward Facing Dog", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 2, video: "Downward-Facing-Dog.mp4", points: ["四足撑起呈倒 V，臀部上顶", "伸直背与腿、脚跟踩向地面", "肩外旋下沉，均匀呼吸"]),
        StretchMove("肘部屈肌拉伸", "Elbow Flexor Stretch", part: .arm, target: "前臂与手臂肌群", kind: "拉伸", difficulty: 1, video: "Elbow Flexor Stretch.mp4", points: ["伸直手臂、掌心向上", "另一手轻压手指向下拉伸前臂屈肌", "缓慢保持、不猛拉"]),
        StretchMove("肘外展旋转肌拉伸", "Elbow Out Rotator Stretch", part: .shoulder, target: "肩部肌群、前臂与手臂肌群", kind: "拉伸", difficulty: 1, video: "Elbow Out Rotator Stretch.mp4", points: ["屈肘外展，另一手辅助旋转", "感受肩袖与前臂拉伸", "动作轻柔、量力保持"]),
        StretchMove("双肘后拉伸展", "Elbows Back Stretch", part: .back, target: "背部肌群、前臂与手臂肌群", kind: "拉伸", difficulty: 1, video: "Elbows Back Stretch.mp4", points: ["双手于背后相扣", "肘向后、肩胛收拢扩胸", "挺胸保持、自然呼吸"]),
        StretchMove("健身球背部拉伸", "Exercise Ball Back Stretch", part: .back, target: "背部肌群", kind: "拉伸", difficulty: 1, video: "Exercise-Ball-Back-Stretch.mp4", points: ["背靠健身球缓慢后仰", "顺球面延展脊柱", "护住头颈、量力保持"]),
        StretchMove("健身球髋屈肌拉伸", "Exercise Ball Hip Flexor Stretch", part: .hip, target: "髋部肌群", kind: "拉伸", difficulty: 1, video: "Exercise Ball Hip Flexor Stretch.mp4", points: ["弓步前压，后侧髋伸展", "可借球稳定身体", "骨盆中立、缓慢加深"]),
        StretchMove("健身球背阔肌拉伸", "Exercise Ball Lat Stretch", part: .back, target: "背阔肌", kind: "拉伸", difficulty: 1, video: "Exercise Ball Lat Stretch.mp4", points: ["跪姿单手扶球前伸", "身体下沉感受背阔与侧腰拉伸", "两侧各做"]),
        StretchMove("肩外旋拉伸", "External Shoulder Rotation Stretch", part: .shoulder, target: "肩部肌群", kind: "拉伸", difficulty: 1, video: "External Shoulder Rotation Stretch.mp4", points: ["大臂贴身屈肘，前臂向外", "用辅助物轻推感受外旋拉伸", "动作轻柔"]),
        StretchMove("手指伸展拉伸", "Finger Extension Stretch", part: .arm, target: "前臂与手臂肌群", kind: "拉伸", difficulty: 1, video: "Finger Extension Stretch.mp4", points: ["伸直手指，另一手轻压向后", "感受手指与手掌拉伸", "缓慢保持"]),
        StretchMove("手指伸肌拉伸", "Finger Extensor Stretch", part: .arm, target: "前臂与手臂肌群", kind: "拉伸", difficulty: 1, video: "Finger Extensor Stretch.mp4", points: ["屈腕握拳向下", "感受手背伸肌拉伸", "轻柔保持"]),
        StretchMove("手指屈肌拉伸", "Finger Flexor Stretch", part: .arm, target: "前臂与手臂肌群", kind: "拉伸", difficulty: 1, video: "Finger Flexor Stretch.mp4", points: ["伸直手臂、掌心向外", "轻拉手指向后伸展屈肌", "缓慢保持"]),
        StretchMove("手指拉伸", "Finger Stretch", part: .arm, target: "前臂与手臂肌群", kind: "拉伸", difficulty: 1, video: "Finger Stretch.mp4", points: ["逐指分开、轻拉伸展", "活动各指关节", "动作轻柔"]),
        StretchMove("鱼式", "Fish Pose Matsyasana", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 2, video: "Fish-Pose-Matsyasana.mp4", points: ["仰卧，肘撑起胸、头顶轻触地", "打开胸腔、伸展颈前", "颈部量力、缓慢进出"]),
        StretchMove("固定杆背部拉伸", "Fixed Bar Back Stretch", part: .back, target: "背部肌群", kind: "拉伸", difficulty: 1, video: "Fixed Bar Back Stretch.mp4", points: ["双手握固定杆、身体后坐", "背阔与肩部延展", "缓慢呼吸保持"]),
        StretchMove("前臂旋前肌拉伸", "Forearm Pronator Stretch", part: .arm, target: "前臂与手臂肌群", kind: "拉伸", difficulty: 1, video: "Forearm Pronator Stretch.mp4", points: ["伸直手臂，旋后前臂", "另一手辅助加深拉伸", "动作轻柔"]),
        StretchMove("前臂墙面滑动", "Forearm Wall Slide", part: .arm, target: "前臂与手臂肌群", kind: "放松/筋膜", difficulty: 1, video: "Forearm Wall Slide.mp4", points: ["前臂贴墙缓慢上下滑动", "肩胛贴附、不耸肩", "活动肩肘"]),
        StretchMove("颈部前屈拉伸", "Forward Flexion Neck Stretch", part: .neck, target: "颈部肌群", kind: "拉伸", difficulty: 1, video: "Forward Flexion Neck Stretch.mp4", points: ["缓慢低头前屈", "感受颈后延展", "轻柔保持、不猛压"]),
        StretchMove("前侧腘绳肌拉伸", "Front Hamstring Stretch", part: .leg, target: "腘绳肌", kind: "拉伸", difficulty: 1, video: "Front Hamstring Stretch.mp4", points: ["一腿前伸脚跟着地、屈髋前俯", "感受腘绳肌拉伸", "背挺直、不弓背"]),
        StretchMove("全莲花式", "Full Lotus Yoga Pose", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 3, video: "Full Lotus Yoga Pose.mp4", points: ["盘坐，双脚依次置于对侧大腿", "脊柱挺直、肩放松", "量力而行、不勉强膝盖"]),
        StretchMove("全蹲灵活性练习", "Full Squat Mobility", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 2, video: "Full-Squat-Mobility.mp4", points: ["脚掌踩实下蹲到底", "挺胸、肘抵膝内撑开", "脚跟不离地"]),
        StretchMove("花环式", "Garland Pose Malasana", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 2, video: "Garland-Pose-Malasana.mp4", points: ["宽蹲到底、双手合十", "肘抵膝内、挺胸打开髋", "脚跟踩实保持"]),
        StretchMove("半月式", "Half Moon Pose Ardha Chandrasana", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 3, video: "Half Moon Pose Ardha Chandrasana.mp4", points: ["单腿支撑，另一手扶地/瑜伽砖", "上侧手臂与腿展开成半月", "收核心保持平衡"]),
        StretchMove("腘绳肌拉伸", "Hamstring Stretch", part: .leg, target: "腘绳肌", kind: "拉伸", difficulty: 1, video: "Hamstring-Stretch.mp4", points: ["坐/站屈髋前俯、腿伸直", "感受大腿后侧拉伸", "背挺直、不弓背猛拉"]),
        StretchMove("快乐婴儿式", "Happy Baby Pose", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 2, video: "Happy-Baby-Pose.mp4", points: ["仰卧抓双脚外侧，膝向腋下", "下背贴地、放松髋部", "可轻微左右摇晃"]),
        StretchMove("英雄式", "Hero Pose Virasana", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 2, video: "Hero Pose Virasana.mp4", points: ["跪坐臀落于两脚之间", "脊柱挺直、肩放松", "膝不适即停"]),
        StretchMove("髋部绕环拉伸", "Hip Circles Stretch", part: .hip, target: "髋部肌群", kind: "拉伸", difficulty: 1, video: "Hip Circles Stretch.mp4", points: ["双手叉腰、髋部画圆", "顺逆时针全幅度各转", "活动髋关节"]),
        StretchMove("髋伸展拉伸", "Hip Extension Stretch", part: .hip, target: "髋部肌群", kind: "拉伸", difficulty: 1, video: "Hip Extension Stretch.mp4", points: ["弓步下沉，后侧髋向前送", "感受髋屈肌拉伸", "骨盆中立保持"]),
        StretchMove("髋外旋肌拉伸", "Hip External Rotator Stretch", part: .hip, target: "髋部肌群", kind: "拉伸", difficulty: 1, video: "Hip External Rotator Stretch.mp4", points: ["仰卧/坐姿，踝搭对侧膝成 4 字", "轻推膝感受臀深部拉伸", "两侧各做"]),
        StretchMove("后脚抬高髋屈肌拉伸", "Hip Flexor Stretch Rear Foot Elevated", part: .hip, target: "髋部肌群", kind: "拉伸", difficulty: 1, video: "Hip Flexor Stretch Rear Foot Elevated.mp4", points: ["后脚搭高呈跪弓步", "髋向前送拉伸髋屈肌与股四头", "挺直上身保持"]),
        StretchMove("进阶髋屈肌和股四头肌拉伸", "Intermediate Hip Flexor And Quad Stretch", part: .leg, target: "股四头肌、髋部肌群", kind: "拉伸", difficulty: 1, video: "Intermediate-Hip-Flexor-And-Quad-Stretch.mp4", points: ["跪弓步，抓后脚向臀靠近", "髋前送、挺胸", "量力保持、不憋腰"]),
        StretchMove("肩内旋拉伸", "Internal Shoulder Rotation Stretch", part: .shoulder, target: "肩部肌群", kind: "拉伸", difficulty: 1, video: "Internal Shoulder Rotation Stretch.mp4", points: ["手背贴后腰，另一手辅助上提", "感受肩前侧/旋转肌拉伸", "轻柔进行"]),
        StretchMove("十字拉伸", "Iron Cross Stretch", part: .fullBody, target: "目标拉伸肌群", kind: "拉伸", difficulty: 1, video: "Iron-Cross-Stretch.mp4", points: ["仰卧双臂展开成十字", "单腿跨过身体扭转触地", "肩贴地、两侧各做"]),
        StretchMove("跪姿背部旋转拉伸", "Kneeling Back Rotation Stretch", part: .back, target: "背部肌群", kind: "拉伸", difficulty: 1, video: "Kneeling Back Rotation Stretch.mp4", points: ["四足跪姿，单手穿过体侧", "胸椎旋转、肩触地", "两侧各做、缓慢呼吸"]),
        StretchMove("跪姿胸部拉伸", "Kneeling Chest Stretch", part: .chest, target: "胸大肌", kind: "拉伸", difficulty: 1, video: "Kneeling Chest Stretch.mp4", points: ["跪姿双手前伸搭高处", "胸口向下沉打开胸肩", "均匀呼吸保持"]),
        StretchMove("跪姿背阔肌拉伸", "Kneeling Lat Stretch", part: .back, target: "背阔肌", kind: "拉伸", difficulty: 1, video: "Kneeling Lat Stretch.mp4", points: ["跪姿双手前伸下压", "感受背阔与腋下延展", "缓慢加深"]),
        StretchMove("跪姿长凳背阔肌拉伸", "Kneeling Lat Stretch on Bench", part: .back, target: "背阔肌", kind: "拉伸", difficulty: 1, video: "Kneeling Lat Stretch on Bench.mp4", points: ["跪姿肘搭长凳、上身下沉", "拉伸背阔肌", "保持背挺直"]),
        StretchMove("仰卧小腿拉伸", "Lying Calf Stretch", part: .leg, target: "小腿肌群", kind: "拉伸", difficulty: 1, video: "Lying Calf Stretch.mp4", points: ["仰卧用带子勾脚掌", "勾脚向身体拉伸小腿", "膝可微屈、缓慢保持"]),
        StretchMove("仰卧下背部拉伸", "Lying Lower Back Stretch", part: .back, target: "背部肌群", kind: "拉伸", difficulty: 1, video: "Lying Lower Back Stretch.mp4", points: ["仰卧抱膝向胸口", "感受下背延展", "下背贴地、缓慢呼吸"]),
        StretchMove("中背部拉伸", "Middle Back Stretch", part: .back, target: "背部肌群", kind: "拉伸", difficulty: 1, video: "Middle-Back-Stretch.mp4", points: ["双手前伸抱物、背部后拱", "延展中背与肩胛间", "缓慢呼吸"]),
        StretchMove("俯卧颈桥", "Neck Bridge Prone", part: .neck, target: "颈部肌群", kind: "放松/筋膜", difficulty: 1, video: "Neck-Bridge-Prone.mp4", points: ["俯卧以额/头轻撑，缓慢活动颈部", "幅度小、力度轻", "颈部不适立即停止"]),
        StretchMove("颈部绕环拉伸", "Neck Circle Stretch", part: .neck, target: "颈部肌群", kind: "拉伸", difficulty: 1, video: "Neck-Circle-Stretch.mp4", points: ["头部缓慢画圈绕环", "顺逆时针全幅度各转", "动作轻柔、不猛甩"]),
        StretchMove("颈部伸展拉伸", "Neck Extension Stretch", part: .neck, target: "颈部肌群", kind: "拉伸", difficulty: 1, video: "Neck-Extension-Stretch.mp4", points: ["缓慢抬头后仰", "感受颈前延展", "轻柔保持、不过仰"]),
        StretchMove("颈伸肌拉伸", "Neck Extensor Stretch", part: .neck, target: "颈部肌群", kind: "拉伸", difficulty: 1, video: "Neck-Extensor-Stretch.mp4", points: ["低头并轻抱后脑", "感受颈后伸肌拉伸", "力度轻柔"]),
        StretchMove("颈屈肌拉伸", "Neck Flexor Stretch", part: .neck, target: "颈部肌群", kind: "拉伸", difficulty: 1, video: "Neck-Flexor-Stretch.mp4", points: ["缓慢抬头后仰拉伸颈前", "下巴上抬", "轻柔保持"]),
        StretchMove("颈部侧向拉伸", "Neck Side Stretch", part: .neck, target: "颈部肌群", kind: "拉伸", difficulty: 1, video: "Neck-Side-Stretch.mp4", points: ["头侧倒向一肩", "另一手可轻引导加深", "两侧各做、不耸肩"]),
        StretchMove("单臂靠墙拉伸", "One Arm Against Wall", part: .fullBody, target: "目标拉伸肌群", kind: "拉伸", difficulty: 1, video: "One Arm Against Wall.mp4", points: ["手臂伸直贴墙", "身体转离打开胸肩前侧", "两侧各做"]),
        StretchMove("单臂背阔肌拉伸", "One Arm Lat Stretch", part: .back, target: "背阔肌", kind: "拉伸", difficulty: 1, video: "One-Arm-Lat-Stretch.mp4", points: ["单手抓握高处、身体下沉侧倾", "拉伸该侧背阔与侧腰", "两侧各做"]),
        StretchMove("开书式拉伸", "Open Book Stretch", part: .fullBody, target: "目标拉伸肌群", kind: "拉伸", difficulty: 2, video: "Open-Book-Stretch.mp4", points: ["侧卧屈膝，双臂前伸合掌", "上侧手臂如翻书向后打开", "胸椎旋转、两侧各做"]),
        StretchMove("过头肱三头肌拉伸", "Overhead Triceps Stretch", part: .arm, target: "前臂与手臂肌群", kind: "拉伸", difficulty: 1, video: "Overhead-Triceps-Stretch.mp4", points: ["手举过头屈肘、手落于背后", "另一手轻压肘加深", "两侧各做"]),
        StretchMove("腓骨肌拉伸", "Peroneals Stretch", part: .leg, target: "小腿肌群", kind: "拉伸", difficulty: 1, video: "Peroneals Stretch.mp4", points: ["脚掌内翻下压", "感受小腿外侧腓骨肌拉伸", "缓慢轻柔"]),
        StretchMove("犁式", "Plow Yoga Pose", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 3, video: "Plow Yoga Pose.mp4", points: ["仰卧抬腿过头、脚尖触地", "双手扶背或贴地", "颈部量力、缓慢进出"]),
        StretchMove("胫骨后肌拉伸", "Posterior Tibialis Stretch", part: .leg, target: "小腿肌群", kind: "拉伸", difficulty: 1, video: "Posterior Tibialis Stretch.mp4", points: ["脚掌外翻、轻压", "拉伸小腿内侧深层", "缓慢保持"]),
        StretchMove("PVC 管外旋", "PVC External Rotation", part: .fullBody, target: "目标拉伸肌群", kind: "肩胛/关节活动", difficulty: 1, video: "Pvc External Rotation.mp4", points: ["握杆大臂贴身屈肘", "前臂向外旋转活动肩袖", "幅度可控、不耸肩"]),
        StretchMove("PVC 管前架位拉伸", "PVC Front Rack Stretch", part: .fullBody, target: "目标拉伸肌群", kind: "拉伸", difficulty: 1, video: "Pvc Front Rack Stretch.mp4", points: ["握杆置于肩前架位", "肘上抬打开手腕与肩活动度", "缓慢加深"]),
        StretchMove("股四头肌拉伸", "Quadriceps Stretch", part: .leg, target: "股四头肌", kind: "拉伸", difficulty: 1, video: "Quadriceps-Stretch.mp4", points: ["站姿抓同侧脚向臀靠拢", "膝并拢、髋前送", "扶物保持平衡"]),
        StretchMove("上举肩部拉伸", "Reaching Up Shoulder Stretch", part: .shoulder, target: "肩部肌群", kind: "拉伸", difficulty: 1, video: "Reaching Up Shoulder Stretch.mp4", points: ["手臂上举伸展", "向上延伸打开肩部", "自然呼吸保持"]),
        StretchMove("前伸上背部拉伸", "Reaching Upper Back Stretch", part: .back, target: "背部肌群", kind: "拉伸", difficulty: 1, video: "Reaching Upper Back Stretch.mp4", points: ["双手十指交叉前推", "背部上段后拱延展", "低头配合、缓慢呼吸"]),
        StretchMove("背部滚动拉伸", "Roll Back Stretch", part: .back, target: "背部肌群", kind: "拉伸", difficulty: 1, video: "Roll Back Stretch.mp4", points: ["抱膝仰卧前后滚动", "按摩并延展背部", "控制节奏、不猛冲"]),
        StretchMove("上背部滚压", "Roll Upper Back", part: .back, target: "背部肌群", kind: "放松/筋膜", difficulty: 1, video: "Roll Upper Back.mp4", points: ["泡沫轴置于上背滚压", "缓慢来回放松肌筋膜", "避开下背与颈椎"]),
        StretchMove("腹部旋转拉伸", "Rotating Stomach Stretch", part: .core, target: "腹部肌群", kind: "拉伸", difficulty: 1, video: "Rotating Stomach Stretch.mp4", points: ["俯撑/站姿，身体缓慢旋转", "延展腹部与侧腰", "两侧各做"]),
        StretchMove("肩胛上提下压", "Scapula Elevation Depression", part: .fullBody, target: "目标拉伸肌群", kind: "肩胛/关节活动", difficulty: 1, video: "Scapula Elevation Depression.mp4", points: ["放松手臂，肩胛上提再下压", "缓慢全幅度活动", "体会肩胛滑动"]),
        StretchMove("肩胛后缩前伸", "Scapula Retraction Protraction", part: .fullBody, target: "目标拉伸肌群", kind: "肩胛/关节活动", difficulty: 1, video: "Scapula Retraction Protraction.mp4", points: ["肩胛后缩夹紧再前伸打开", "缓慢全幅度", "手臂放松、不耸肩"]),
        StretchMove("坐姿脊柱扭转", "Seated Spinal Twist", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 2, video: "Seated-Spinal-Twist.mp4", points: ["坐姿屈膝、上身向后扭转", "肘抵膝外辅助加深", "挺直脊柱、两侧各做"]),
        StretchMove("单侧直腿拉伸", "Single Straight Leg Stretch", part: .fullBody, target: "目标拉伸肌群", kind: "拉伸", difficulty: 1, video: "Single Straight Leg Stretch.mp4", points: ["仰卧抬一腿伸直拉向身体", "另一腿伸直贴地", "勾脚拉伸腘绳肌、两侧各做"]),
        StretchMove("狮身人面式", "Sphinx", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 2, video: "Sphinx.mp4", points: ["俯卧前臂撑地抬起上身", "肩下沉、打开胸腔", "下背放松不憋"]),
        StretchMove("脊柱前屈拉伸", "Spine Stretch Forward", part: .back, target: "背部肌群", kind: "拉伸", difficulty: 1, video: "Spine Stretch Forward.mp4", points: ["坐姿伸腿，逐节向前卷曲下俯", "延展脊柱与腘绳肌", "缓慢呼气加深"]),
        StretchMove("拇指拉伸", "Thumb Stretch", part: .arm, target: "前臂与手臂肌群", kind: "拉伸", difficulty: 1, video: "Thumb Stretch.mp4", points: ["轻拉拇指向后/向下", "伸展拇指各方向", "动作轻柔"]),
        StretchMove("按摩棒前臂放松", "Tiger Tail Forearm", part: .arm, target: "前臂与手臂肌群", kind: "放松/筋膜", difficulty: 1, video: "Tiger Tail Forearm.mp4", points: ["用按摩棒滚压前臂", "缓慢来回放松肌筋膜", "力度适中"]),
        StretchMove("按摩棒颈部放松", "Tiger Tail Neck", part: .neck, target: "颈部肌群", kind: "放松/筋膜", difficulty: 1, video: "Tiger Tail Neck.mp4", points: ["按摩棒轻滚颈部两侧", "避开颈椎正中", "力度轻柔"]),
        StretchMove("树式", "Tree Pose Vrksasana", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 2, video: "Tree Pose Vrksasana.mp4", points: ["单腿站立，另一脚掌贴支撑腿内侧", "双手合十、收核心保持平衡", "目视前方一点稳定"]),
        StretchMove("三角式", "Triangle Pose Trikonasana", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 2, video: "Triangle Pose Trikonasana.mp4", points: ["双脚开立，一手向下扶腿/地", "另一手向上展开成三角", "挺直躯干、不塌腰"]),
        StretchMove("肱三头肌拉伸", "Triceps Stretch", part: .arm, target: "前臂与手臂肌群", kind: "拉伸", difficulty: 1, video: "Triceps Stretch.mp4", points: ["手举过头屈肘落向背后", "另一手轻压肘加深", "两侧各做"]),
        StretchMove("上背部拉伸", "Upper Back Stretch", part: .back, target: "背部肌群", kind: "拉伸", difficulty: 1, video: "Upper-Back-Stretch.mp4", points: ["双手前伸合抱、背部后拱", "延展上背与肩胛间", "缓慢呼吸"]),
        StretchMove("上犬式", "Upward Facing Dog", part: .fullBody, target: "目标拉伸肌群", kind: "瑜伽体式", difficulty: 2, video: "Upward-Facing-Dog.mp4", points: ["俯卧伸臂撑起上身、大腿离地", "胸口前推、肩下沉", "下背不挤压"]),
        StretchMove("手腕绕环", "Wrist Circles", part: .arm, target: "前臂与手臂肌群", kind: "绕环", difficulty: 1, video: "Wrist Circles.mp4", points: ["双手握拳、手腕画圈", "顺逆时针全幅度各转", "活动腕关节"]),
        StretchMove("腕伸肌拉伸", "Wrist Extensor Stretch", part: .arm, target: "前臂与手臂肌群", kind: "拉伸", difficulty: 1, video: "Wrist Extensor Stretch.mp4", points: ["伸臂屈腕、掌心向内下压", "拉伸前臂伸肌（手背侧）", "缓慢保持"]),
        StretchMove("腕屈肌拉伸", "Wrist Flexor Stretch", part: .arm, target: "前臂与手臂肌群", kind: "拉伸", difficulty: 1, video: "Wrist Flexor Stretch.mp4", points: ["伸臂掌心向外、轻拉手指向后", "拉伸前臂屈肌（掌侧）", "缓慢保持"]),
    ]

    /// 某部位下的全部拉伸动作。
    static func moves(in part: StretchPart) -> [StretchMove] {
        moves.filter { $0.part == part }
    }

    /// 各部位计数（用于 tab 标签）。
    static func count(in part: StretchPart) -> Int {
        moves(in: part).count
    }

    /// 按英文名查找单个动作（供成套方案引用）。
    static func move(_ nameEn: String) -> StretchMove? {
        moves.first { $0.nameEn == nameEn }
    }

    /// 关键词搜索（中文名 / 英文名 / 目标 / 类型）。
    static func search(_ keyword: String) -> [StretchMove] {
        let key = keyword.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return [] }
        return moves.filter {
            $0.name.lowercased().contains(key)
                || $0.nameEn.lowercased().contains(key)
                || $0.target.lowercased().contains(key)
                || $0.kind.lowercased().contains(key)
        }
    }
}

// MARK: - 拉伸成套方案（顶部「拉伸」tab 的横滑「训练计划」）

/// 方案中的一个动作条目：引用 StretchData 动作（按英文名）+ 建议保持时长。
struct StretchRoutineItem: Identifiable {
    let id = UUID()
    let moveNameEn: String      // 对应 StretchData.moves 的 nameEn
    let holdText: String        // 如 "左右各 30 秒" / "保持 60 秒"

    var move: StretchMove? { StretchData.move(moveNameEn) }
}

/// 一套拉伸方案（多动作按顺序编排，供快速跟练）。
struct StretchRoutine: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String        // 一句话目标
    let level: String           // 入门 / 进阶
    let durationMin: Int        // 预计时长
    let difficultyStars: Int    // 难度 1–5（点阵展示）
    let intensityStars: Int     // 强度 1–5（点阵展示）
    let items: [StretchRoutineItem]

    /// 能解析到的动作（跳过缺失引用）。
    var moves: [StretchMove] { items.compactMap(\.move) }
}

/// 拉伸成套方案数据。内容可自由增补/调整，引用的 nameEn 需与 StretchData.moves 一致。
enum StretchRoutines {
    static let all: [StretchRoutine] = [
        StretchRoutine(
            title: "晨间唤醒",
            subtitle: "起床后激活全身，唤醒关节活动度",
            level: "入门", durationMin: 6, difficultyStars: 1, intensityStars: 2,
            items: [
                StretchRoutineItem(moveNameEn: "Cat Cow Stretch", holdText: "8–10 次呼吸"),
                StretchRoutineItem(moveNameEn: "Arm Circles", holdText: "前后各 30 秒"),
                StretchRoutineItem(moveNameEn: "Hip Circles Stretch", holdText: "左右各 30 秒"),
                StretchRoutineItem(moveNameEn: "Downward Facing Dog", holdText: "保持 45 秒"),
                StretchRoutineItem(moveNameEn: "Full Squat Mobility", holdText: "保持 45 秒"),
            ]
        ),
        StretchRoutine(
            title: "久坐放松",
            subtitle: "缓解颈肩与上背僵硬，适合办公间隙",
            level: "入门", durationMin: 8, difficultyStars: 1, intensityStars: 1,
            items: [
                StretchRoutineItem(moveNameEn: "Chin to Chest Stretch", holdText: "保持 30 秒"),
                StretchRoutineItem(moveNameEn: "Neck Side Stretch", holdText: "左右各 30 秒"),
                StretchRoutineItem(moveNameEn: "Chest and Front of Shoulder Stretch", holdText: "左右各 30 秒"),
                StretchRoutineItem(moveNameEn: "Reaching Upper Back Stretch", holdText: "保持 30 秒"),
                StretchRoutineItem(moveNameEn: "Seated Spinal Twist", holdText: "左右各 30 秒"),
            ]
        ),
        StretchRoutine(
            title: "睡前舒缓",
            subtitle: "释放下背与腿部张力，帮助放松入睡",
            level: "入门", durationMin: 7, difficultyStars: 1, intensityStars: 1,
            items: [
                StretchRoutineItem(moveNameEn: "Lying Lower Back Stretch", holdText: "保持 45 秒"),
                StretchRoutineItem(moveNameEn: "Kneeling Back Rotation Stretch", holdText: "左右各 30 秒"),
                StretchRoutineItem(moveNameEn: "Hamstring Stretch", holdText: "左右各 45 秒"),
                StretchRoutineItem(moveNameEn: "Happy Baby Pose", holdText: "保持 60 秒"),
                StretchRoutineItem(moveNameEn: "Back Relaxation", holdText: "保持 60 秒"),
            ]
        ),
        StretchRoutine(
            title: "全身活动度",
            subtitle: "打开髋、胸椎与肩，进阶灵活度训练",
            level: "进阶", durationMin: 10, difficultyStars: 3, intensityStars: 3,
            items: [
                StretchRoutineItem(moveNameEn: "Full Squat Mobility", holdText: "保持 60 秒"),
                StretchRoutineItem(moveNameEn: "Garland Pose Malasana", holdText: "保持 60 秒"),
                StretchRoutineItem(moveNameEn: "Open Book Stretch", holdText: "左右各 45 秒"),
                StretchRoutineItem(moveNameEn: "Cobra Yoga Pose", holdText: "8–10 次呼吸"),
                StretchRoutineItem(moveNameEn: "Downward Facing Dog", holdText: "保持 60 秒"),
            ]
        ),
    ]

    static var count: Int { all.count }
}
