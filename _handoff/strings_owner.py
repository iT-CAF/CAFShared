# -*- coding: utf-8 -*-
"""Strings of the owner face (cafbio-mobile). Merged into the table by gen_strings.py."""
OWNER = {
# errors of the owner API
"err.bad_login": ("البريد أو كلمة المرور غير صحيحة", "Wrong email or password"),
"err.invalid_login": ("أدخل البريد وكلمة المرور", "Enter your email and password"),
"err.twofa": ("الحسابات ذات التحقق بخطوتين تدخل من الموقع حاليًا", "Accounts with two-step verification sign in on the website for now"),
"err.no_program": ("تظهر الفروع والموظفون بعد إعداد صفحة النشاط", "Branches and staff appear once the business page is set up"),
"err.team": ("أعضاء فريق العمل يستخدمون الموقع", "Workspace members use the website"),
"err.reuse": ("انتهت الجلسة لأسباب أمنية، سجّل الدخول من جديد", "Session ended for security, sign in again"),
# sign in
"owner.login_title": ("دخول صاحب النشاط", "Owner sign-in"), "owner.login_subtitle": ("بنفس بريدك وكلمة مرورك في it-caf.com", "With your it-caf.com email and password"),
"owner.email": ("البريد الإلكتروني", "Email"), "owner.email_placeholder": ("name@example.com", "name@example.com"),
"owner.password": ("كلمة المرور", "Password"), "owner.password_placeholder": ("••••••••", "••••••••"),
"owner.sign_in": ("دخول", "Sign in"), "owner.login_missing": ("أدخل البريد وكلمة المرور", "Enter your email and password"),
"owner.login_note": ("لا تُحفظ كلمة المرور في التطبيق؛ يحتفظ جهازك بمفتاح دخول مشفّر يمكنك إلغاؤه في أي وقت.", "Your password isn't stored; this device keeps an encrypted sign-in key you can revoke any time."),
"owner.change_role": ("تغيير طريقة الاستخدام", "Change how I use the app"), "owner.session_ended": ("انتهت الجلسة، سجّل الدخول من جديد", "Your session ended, please sign in again"),
# tabs
"owner.tab_overview": ("نظرة عامة", "Overview"), "owner.tab_team": ("الفريق", "Team"), "owner.tab_account": ("حسابي", "Account"),
# overview
"owner.today": ("اليوم", "Today"), "owner.branches": ("الفروع", "Branches"), "owner.minutes": ("د", "min"),
"owner.t_orders": ("الطلبات", "Orders"), "owner.t_waiting": ("بانتظار التسليم", "Waiting"), "owner.t_prep": ("متوسط التحضير", "Avg. prep"),
"owner.t_members": ("أعضاء جدد", "New members"), "owner.t_stamps": ("الأختام والنقاط", "Stamps & points"), "owner.t_rewards": ("مكافآت متاحة", "Rewards ready"),
"owner.no_branches": ("لا فروع بعد", "No branches yet"), "owner.no_branches_body": ("أضف فرعًا من تبويب الفريق.", "Add a branch from the Team tab."),
"owner.branch_off": ("موقوف", "Off"), "owner.last_seen": ("آخر نشاط %@", "Last active %@"), "owner.load_a11y": ("%lld طلبات من أصل %lld", "%lld orders of %lld"),
# team
"owner.staff": ("الموظفون", "Staff"), "owner.staff_footer": ("الرمز السري لا يُحفظ في التطبيق ولا يظهر إلا مرة واحدة عند إنشائه أو إعادة تعيينه.", "A PIN is never stored in the app and is shown only once, when created or reset."),
"owner.staff_count": ("%lld موظف", "%lld staff"), "owner.locked": ("مقفل", "Locked"), "owner.inactive": ("معطّل", "Inactive"),
"owner.add_branch": ("إضافة فرع", "Add a branch"), "owner.add_staff": ("إضافة موظف", "Add staff"), "owner.staff_actions": ("إجراءات الموظف", "Staff actions"),
"owner.branch_name": ("اسم الفرع", "Branch name"), "owner.branch_name_placeholder": ("مثال: فرع الشمال", "e.g. North branch"),
"owner.branch_address": ("العنوان (اختياري)", "Address (optional)"), "owner.branch_address_placeholder": ("الحي أو الشارع", "District or street"),
"owner.staff_name": ("اسم الموظف", "Staff name"), "owner.staff_name_placeholder": ("الاسم الكامل", "Full name"),
"owner.role": ("الدور", "Role"), "owner.branch": ("الفرع", "Branch"), "owner.all_branches": ("كل الفروع", "All branches"),
"role.handover": ("تسليم", "Handover"), "role.preparer": ("تحضير", "Preparation"), "role.loyalty": ("ولاء", "Loyalty"),
"owner.role_hint_cashier": ("يسجّل الطلبات والولاء ويستلم الدفع.", "Takes orders, loyalty and payments."),
"owner.role_hint_manager": ("كل صلاحيات الكاشير مع الأصناف والإيقاف والملخصات.", "Cashier rights plus menu, pause and summaries."),
"owner.role_hint_handover": ("يسلّم الطلبات الجاهزة فقط.", "Hands over ready orders only."),
"owner.role_hint_preparer": ("يرى شاشة التحضير فقط.", "Sees the preparation screen only."),
"owner.role_hint_loyalty": ("يضيف الأختام والنقاط فقط.", "Adds stamps and points only."),
"owner.pin_note": ("يُنشأ للموظف رمز سري من 6 أرقام ويظهر لك مرة واحدة.", "A 6-digit PIN is created and shown to you once."),
"owner.create_staff": ("إنشاء الموظف", "Create staff member"), "owner.activate": ("تفعيل", "Activate"), "owner.deactivate": ("تعطيل", "Deactivate"),
"owner.reset_pin": ("إعادة تعيين الرمز السري", "Reset PIN"), "owner.reset_confirm": ("إعادة تعيين الرمز السري؟", "Reset this PIN?"),
"owner.reset_body": ("يُنشأ رمز جديد ويُسجَّل خروج الموظف من أجهزته.", "A new PIN is created and the person is signed out everywhere."),
"owner.pin_title": ("الرمز السري الجديد", "New PIN"), "owner.pin_once": ("يظهر هذا الرمز مرة واحدة فقط. سلّمه للموظف الآن.", "This PIN is shown only once. Hand it to the person now."),
"owner.copy": ("نسخ", "Copy"), "owner.copied": ("تم النسخ", "Copied"),
# branch link
"owner.link_hint": ("امسح الرمز من جوال الكاشير أو أرسل له الرابط. الرابط سرّي لهذا الفرع.", "Scan from the cashier's phone or send them the link. It is private to this branch."),
"owner.copy_link": ("نسخ الرابط", "Copy link"), "owner.share": ("مشاركة", "Share"), "owner.open_as_cashier": ("فتح كاشير هذا الفرع هنا", "Open this branch as cashier here"),
"owner.activate_branch": ("تفعيل الفرع", "Activate branch"), "owner.deactivate_branch": ("إيقاف الفرع", "Deactivate branch"),
"owner.rotate": ("إنشاء رابط جديد", "Create a new link"), "owner.rotate_confirm": ("إنشاء رابط جديد للفرع؟", "Create a new link for this branch?"),
"owner.rotate_body": ("يتوقف الرابط الحالي فورًا ويخرج كل من سجّل به.", "The current link stops working at once and everyone using it is signed out."),
"owner.rotate_note": ("استخدمه إذا ضاع الجهاز أو غادر موظف.", "Use it if a device is lost or someone leaves."), "owner.qr_a11y": ("رمز QR لرابط الكاشير", "QR code of the cashier link"),
# account
"owner.account": ("الحساب", "Account"), "owner.businesses": ("أنشطتي", "My businesses"), "owner.modes": ("طريقة الاستخدام", "Mode"),
"owner.cashier_mode": ("العمل ككاشير", "Work as cashier"), "owner.modes_footer": ("يمكنك التبديل بين وجه المالك والكاشير متى شئت.", "Switch between owner and cashier any time."),
"owner.devices": ("أجهزتي", "My devices"), "owner.devices_footer": ("كل جهاز سجّل الدخول له مفتاح مستقل. اخرج من أي جهاز لا تعرفه.", "Each signed-in device has its own key. Sign out any device you don't recognise."),
"owner.this_device": ("هذا الجهاز", "This device"), "owner.sign_out_device": ("خروج", "Sign out"),
"owner.sign_out": ("تسجيل الخروج", "Sign out"), "owner.sign_out_confirm": ("تسجيل الخروج من هذا الجهاز؟", "Sign out of this device?"),
"more.owner_mode": ("وجه صاحب النشاط", "Owner mode"),
}

# The owner team screen renders role.\(role) dynamically; these two keys lived in the cashier table and are not in it any more.
OWNER_ROLES = {
"role.manager": ("مدير", "Manager"), "role.cashier": ("كاشير", "Cashier"),
}
