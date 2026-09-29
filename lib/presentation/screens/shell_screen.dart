import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../providers/chat_provider.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tmdb_provider.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/floating_island_navigation_bar.dart';
import '../widgets/side_transfer_dock.dart';
import 'chat/chat_screen.dart';
import 'discover/discover_screen.dart';
import 'library/library_screen.dart';
import 'profile_screen.dart';
import 'settings/settings_screen.dart';

final shellNavigationProvider = StateProvider<int>((ref) => 0);
final GlobalKey<ScaffoldState> shellScaffoldKey = GlobalKey<ScaffoldState>();

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> with TickerProviderStateMixin {
  late final PageController _pageController;

  late final AnimationController _dockSlideController;
  late final Animation<Offset> _dockSlideAnimation;

  late final AnimationController _dockIconController;
  late final Animation<Offset> _dockIconSlideAnimation;
  late final Animation<double> _dockIconOpacityAnimation;

  late final AnimationController _drawerController;
  late final Animation<Offset> _drawerSlideAnimation;

  // Alt menünün soldan çıkan ikizi (Side Transfer Dock) için kontroller
  late final AnimationController _sideDockSlideController;
  late final Animation<Offset> _sideDockSlideAnimation;
  late final AnimationController _sideDockItemController;

  Timer? _dockSinkTimer;
  Timer? _sideDockEntryTimer;
  Timer? _sideDockTimer;

  static const List<Widget> _screens = [
    _KeepAlivePage(child: ChatScreen()),
    _KeepAlivePage(child: SafeArea(bottom: false, child: ProfileScreen())),
    _KeepAlivePage(child: SafeArea(bottom: false, child: DiscoverScreen())),
    _KeepAlivePage(child: SafeArea(bottom: false, child: LibraryScreen())),
    _KeepAlivePage(child: SettingsScreen()),
  ];

  @override
  void initState() {
    super.initState();

    final initialTab = ref.read(shellNavigationProvider);
    _pageController = PageController(initialPage: initialTab);

    // 1. Bottom Dock vertical sliding controller
    _dockSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
      reverseDuration: const Duration(milliseconds: 360),
      value: initialTab == 0 ? 0.0 : 1.0,
    );

    _dockSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.35), // Hidden below bottom edge
      end: Offset.zero,             // Resting floating position
    ).animate(
      CurvedAnimation(
        parent: _dockSlideController,
        curve: const Cubic(0.22, 1.0, 0.36, 1.05), // Ultra smooth micro bounce
        reverseCurve: Curves.easeInOutCubic,
      ),
    );

    // 2. Dock Icons horizontal slide-left & fade-out controller
    _dockIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 280),
      value: initialTab == 0 ? 0.0 : 1.0,
    );

    // Icons strongly drift -200px to the left as they flow into the left corner
    _dockIconSlideAnimation = Tween<Offset>(
      begin: const Offset(-200.0, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _dockIconController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic, // Accelerates cleanly into left corner
      ),
    );

    _dockIconOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _dockIconController,
        curve: Curves.easeOut,
        reverseCurve: const Interval(0.25, 1.0, curve: Curves.easeInOut),
      ),
    );

    // 3. Left Side Drawer animation controller (320ms open, 260ms close)
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 260),
    );

    _drawerSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _drawerController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      ),
    );

    // 4. Side Transfer Dock (Alt menünün dikey ikizi) controllers
    _sideDockSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 280),
    );

    _sideDockSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.35, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _sideDockSlideController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      ),
    );

    _sideDockItemController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340), // Ultra-snappy upward cascade
    );
  }

  @override
  void dispose() {
    _dockSinkTimer?.cancel();
    _sideDockEntryTimer?.cancel();
    _sideDockTimer?.cancel();
    _pageController.dispose();
    _dockSlideController.dispose();
    _dockIconController.dispose();
    _drawerController.dispose();
    _sideDockSlideController.dispose();
    _sideDockItemController.dispose();
    super.dispose();
  }

  void _openDrawer() {
    final isAnimationsEnabled = ref.read(settingsProvider).isAnimationsEnabled;
    if (isAnimationsEnabled) {
      _drawerController.forward();
    } else {
      _drawerController.value = 1.0;
    }
  }

  void _closeDrawer() {
    final isAnimationsEnabled = ref.read(settingsProvider).isAnimationsEnabled;
    if (isAnimationsEnabled) {
      _drawerController.reverse();
    } else {
      _drawerController.value = 0.0;
    }
  }

  void _triggerSideTransferDock() {
    _sideDockTimer?.cancel();
    _sideDockSlideController.forward();
    _sideDockItemController.forward(from: 0.0);

    // Yan dock ekranda ~400ms kalarak transferi hissettirir, ardından anında sola çekilir
    _sideDockTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (ref.read(shellNavigationProvider) == 0 && _sideDockSlideController.value > 0.5) {
        _sideDockSlideController.reverse();
      }
    });
  }

  void _navigateToTab(int newIndex) {
    _dockSinkTimer?.cancel();
    _sideDockEntryTimer?.cancel();
    _sideDockTimer?.cancel();
    final currentIndex = ref.read(shellNavigationProvider);
    if (currentIndex == newIndex) return;

    final isAnimationsEnabled = ref.read(settingsProvider).isAnimationsEnabled;

    ref.read(shellNavigationProvider.notifier).state = newIndex;

    if (!isAnimationsEnabled) {
      if (newIndex == 0) {
        _dockIconController.value = 0.0;
        _dockSlideController.value = 0.0;
        _sideDockSlideController.value = 0.0;
      } else {
        _sideDockSlideController.value = 0.0;
        _closeDrawer();
        _dockSlideController.value = 1.0;
        _dockIconController.value = 1.0;
      }
      return;
    }

    if (newIndex == 0) {
      // KİNETİK TRANSFER AKIŞI:
      // 1. İkonlar sol köşeye doğru hızlanarak akar (-200px)
      _dockIconController.reverse();

      // 2. İkonlar sol kenara varırken (~100ms sonra), alt dock tabanı aşağı batar
      _dockSinkTimer = Timer(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        _dockSlideController.reverse();
      });

      // 3. İkonlar sol kenara girdiği anda (~120ms), ekranın ortasındaki dikey dock soldan çıkar
      // ve ikonlar aşağıdan yukarıya doğru sırayla yükselir!
      _sideDockEntryTimer = Timer(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        _triggerSideTransferDock();
      });
    } else {
      // Diğer sekmelere geçerken: yan dock veya çekmece açıksa kapanır, alt menü geri gelir
      if (_sideDockSlideController.value > 0) {
        _sideDockSlideController.reverse();
      }
      _closeDrawer();
      _dockSlideController.forward();
      _dockIconController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(shellNavigationProvider);
    final isAnimationsEnabled = ref.watch(settingsProvider).isAnimationsEnabled;

    ref.listen<int>(shellNavigationProvider, (previous, next) {
      if (_pageController.hasClients) {
        if (isAnimationsEnabled) {
          _pageController.animateToPage(
            next,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
          );
        } else {
          _pageController.jumpToPage(next);
        }
      }
      if (next != 0 && _dockSlideController.value == 0.0) {
        if (isAnimationsEnabled) {
          _dockSlideController.forward();
          _dockIconController.forward();
        } else {
          _dockSlideController.value = 1.0;
          _dockIconController.value = 1.0;
        }
      }
    });

    return Scaffold(
      key: shellScaffoldKey,
      body: Stack(
        children: [
          // 1. Core Screen Content with Header AppBar (Sadece AI Sohbet [0] ve Ayarlar [4] sekmelerinde gösterilir)
          Column(
            children: [
              if (currentIndex == 0 || currentIndex == 4)
                _buildShellAppBar(context, ref, currentIndex),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _screens,
                ),
              ),
            ],
          ),

          // 2. iOS Frosted Glass Floating Island (Icons drift left first, then dock sinks down)
          AnimatedBuilder(
            animation: Listenable.merge([_dockSlideController, _dockIconController]),
            builder: (context, child) {
              return SlideTransition(
                position: _dockSlideAnimation,
                child: IgnorePointer(
                  ignoring: currentIndex == 0,
                  child: FloatingIslandNavigationBar(
                    currentIndex: currentIndex,
                    onTabSelected: _navigateToTab,
                    iconOpacity: _dockIconOpacityAnimation.value,
                    iconOffset: _dockIconSlideAnimation.value,
                    isAnimationsEnabled: isAnimationsEnabled,
                  ),
                ),
              );
            },
          ),

          // 3. Side Transfer Dock (Alt menünün dikey ikizi - sadece transfer anında gösterilir)
          AnimatedBuilder(
            animation: _sideDockSlideController,
            builder: (context, child) {
              if (_sideDockSlideController.value == 0.0 &&
                  _sideDockSlideController.status == AnimationStatus.dismissed) {
                return const SizedBox.shrink();
              }
              return Positioned(
                left: 14,
                top: 0,
                bottom: 0,
                child: Center(
                  child: SlideTransition(
                    position: _sideDockSlideAnimation,
                    child: SideTransferDock(
                      currentIndex: currentIndex,
                      itemAnimation: _sideDockItemController,
                      onTabSelected: (index) {
                        _sideDockSlideController.reverse();
                        _navigateToTab(index);
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          // 4. Smooth Full-Screen Animated Drawer (Menü butonuna tıklanıldığında açılan normal menümüz)
          _buildSmoothDrawer(context),
        ],
      ),
    );
  }

  Widget _buildSmoothDrawer(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth > 600
        ? 265.0
        : (screenWidth * 0.76).clamp(240.0, 275.0);

    return AnimatedBuilder(
      animation: _drawerController,
      builder: (context, child) {
        final progress = _drawerController.value;
        if (progress == 0.0) return const SizedBox.shrink();

        return Positioned.fill(
          child: Stack(
            children: [
              // Semi-transparent backdrop barrier
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeDrawer,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.22 * progress),
                  ),
                ),
              ),

              // Drawer Content Panel (Floating Apple Frosted Glass Card)
              Positioned(
                top: MediaQuery.of(context).padding.top + 14,
                bottom: 16,
                left: 14,
                width: drawerWidth,
                child: SlideTransition(
                  position: _drawerSlideAnimation,
                  child: Material(
                    elevation: 0,
                    color: Colors.transparent,
                    child: AppNavigationDrawerContent(
                      onClose: _closeDrawer,
                      itemAnimation: null,
                      onTabSelected: (index) {
                        _closeDrawer();
                        _navigateToTab(index);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShellAppBar(BuildContext context, WidgetRef ref, int currentIndex) {
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Row(
        children: [
          // 1. Menü Sembolü - SADECE AI Sohbet ekranında (Tab 0) gösterilir!
          if (currentIndex == 0) ...[
            IconButton(
              onPressed: _openDrawer,
              icon: const Icon(Icons.menu_rounded, color: AppColors.primaryAmber, size: 24),
              tooltip: 'Menü',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            const SizedBox(width: 8),
          ],

          // 2. CineAI Logo ve Başlık
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryAmber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.movie_filter_rounded, color: AppColors.primaryAmber, size: 22),
              ),
              const SizedBox(width: 8),
              Text(
                'CineAI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textHigh,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),

          const SizedBox(width: 10),
          Container(
            height: 18,
            width: 1,
            color: AppColors.border,
          ),
          const SizedBox(width: 12),

          // Active Page Title
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Align(
                key: ValueKey<int>(currentIndex),
                alignment: Alignment.centerLeft,
                child: Text(
                  _getScreenTitle(currentIndex),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMedium,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: KeyedSubtree(
            key: ValueKey<int>(currentIndex),
            child: _buildScreenAction(context, ref, currentIndex),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  String _getScreenTitle(int index) {
    switch (index) {
      case 0:
        return 'AI Sohbet & Öneri';
      case 1:
        return 'Profil & İstatistikler';
      case 2:
        return 'Keşfet';
      case 3:
        return 'Kütüphane';
      case 4:
        return 'Ayarlar';
      default:
        return '';
    }
  }

  Widget _buildScreenAction(BuildContext context, WidgetRef ref, int index) {
    switch (index) {
      case 0:
        return const SizedBox.shrink();
      case 1:
        return IconButton(
          tooltip: 'Yenile',
          icon: Icon(Icons.refresh_rounded, color: AppColors.textMedium),
          onPressed: () => ref.read(libraryProvider.notifier).loadLibrary(),
        );
      case 2:
        return IconButton(
          tooltip: 'Trendleri Yenile',
          icon: Icon(Icons.refresh_rounded, color: AppColors.textMedium),
          onPressed: () => ref.read(tmdbProvider.notifier).fetchTrending(),
        );
      case 3:
        return IconButton(
          tooltip: 'Kütüphaneyi Yenile',
          icon: Icon(Icons.refresh_rounded, color: AppColors.textMedium),
          onPressed: () => ref.read(libraryProvider.notifier).loadLibrary(),
        );
      case 4:
        return const SizedBox.shrink();
      default:
        return const SizedBox.shrink();
    }
  }
}

class _KeepAlivePage extends StatefulWidget {
  final Widget child;
  const _KeepAlivePage({required this.child});

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
