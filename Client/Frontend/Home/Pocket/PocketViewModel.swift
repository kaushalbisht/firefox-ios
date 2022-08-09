// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Storage
import Shared

class PocketViewModel {

    struct UX {
        static let numberOfItemsInColumn = 3
        static let discoverMoreMaxFontSize: CGFloat = 55 // Title 3 xxxLarge
        static let fractionalWidthiPhonePortrait: CGFloat = 0.93
        static let fractionalWidthiPhoneLanscape: CGFloat = 0.46
    }

    // MARK: - Properties

    private let pocketAPI: Pocket
    private let pocketSponsoredAPI: PocketSponsoredStoriesProviding

    var isZeroSearch: Bool
    private var hasSentPocketSectionEvent = false

    private lazy var storyProvider: StoryProvider = {
        StoryProvider(pocketAPI: pocketAPI, pocketSponsoredAPI: pocketSponsoredAPI) { [weak self] in
            self?.featureFlags.isFeatureEnabled(.sponsoredPocket, checking: .buildAndUser) == true
        }
    }()

    var onTapTileAction: ((URL) -> Void)?
    var onLongPressTileAction: ((Site, UIView?) -> Void)?
    var onScroll: (([NSCollectionLayoutVisibleItem]) -> Void)?

    private(set) var pocketStoriesViewModels: [PocketStandardCellViewModel] = []

    init(pocketAPI: Pocket,
         pocketSponsoredAPI: PocketSponsoredStoriesProviding,
         isZeroSearch: Bool = false) {
        self.isZeroSearch = isZeroSearch
        self.pocketAPI = pocketAPI
        self.pocketSponsoredAPI = pocketSponsoredAPI
    }

    private func bind(pocketStoryViewModel: PocketStandardCellViewModel) {
        pocketStoryViewModel.onTap = { [weak self] indexPath in
            self?.recordTapOnStory(index: indexPath.row)
            let siteUrl = self?.pocketStoriesViewModels[indexPath.row].url
            siteUrl.map { self?.onTapTileAction?($0) }
        }

        pocketStoriesViewModels.append(pocketStoryViewModel)
    }

    // The dimension of a cell
    // Fractions for iPhone to only show a slight portion of the next column
    static var widthDimension: NSCollectionLayoutDimension {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .absolute(PocketStandardCell.UX.cellWidth) // iPad
        } else if UIWindow.isLandscape {
            return .fractionalWidth(UX.fractionalWidthiPhoneLanscape)
        } else {
            return .fractionalWidth(UX.fractionalWidthiPhonePortrait)
        }
    }

    var numberOfCells: Int {
        return !pocketStoriesViewModels.isEmpty ? pocketStoriesViewModels.count + 1 : 0
    }

    func isStoryCell(index: Int) -> Bool {
        return index < pocketStoriesViewModels.count
    }

    func getSitesDetail(for index: Int) -> Site {
        if isStoryCell(index: index) {
            return Site(url: pocketStoriesViewModels[index].url?.absoluteString ?? "", title: pocketStoriesViewModels[index].title)
        } else {
            return Site(url: Pocket.MoreStoriesURL.absoluteString, title: .FirefoxHomepage.Pocket.DiscoverMore)
        }
    }

    // MARK: - Telemetry

    func recordSectionHasShown() {
        if !hasSentPocketSectionEvent {
            TelemetryWrapper.recordEvent(category: .action, method: .view, object: .pocketSectionImpression, value: nil, extras: nil)
            hasSentPocketSectionEvent = true
        }
    }

    func recordTapOnStory(index: Int) {
        // Pocket site extra
        let key = TelemetryWrapper.EventExtraKey.pocketTilePosition.rawValue
        let siteExtra = [key: "\(index)"]

        // Origin extra
        let originExtra = TelemetryWrapper.getOriginExtras(isZeroSearch: isZeroSearch)
        let extras = originExtra.merge(with: siteExtra)

        TelemetryWrapper.recordEvent(category: .action, method: .tap, object: .pocketStory, value: nil, extras: extras)
    }

    // MARK: - Private

    private func updatePocketSites() async {
        let stories = await storyProvider.fetchPocketStories()
        pocketStoriesViewModels = []
        // Add the story in the view models list
        for story in stories {
            bind(pocketStoryViewModel: .init(story: story))
        }
    }

    func showDiscoverMore() {
        onTapTileAction?(Pocket.MoreStoriesURL)
    }
}

// MARK: HomeViewModelProtocol
extension PocketViewModel: HomepageViewModelProtocol, FeatureFlaggable {

    var sectionType: HomepageSectionType {
        return .pocket
    }

    var headerViewModel: LabelButtonHeaderViewModel {
        return LabelButtonHeaderViewModel(title: HomepageSectionType.pocket.title,
                                          titleA11yIdentifier: AccessibilityIdentifiers.FirefoxHomepage.SectionTitles.pocket,
                                          isButtonHidden: true)
    }

    func section(for traitCollection: UITraitCollection) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(PocketStandardCell.UX.cellHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: PocketViewModel.widthDimension,
            heightDimension: .estimated(PocketStandardCell.UX.cellHeight)
        )

        let subItems = Array(repeating: item, count: UX.numberOfItemsInColumn)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: subItems)
        group.interItemSpacing = PocketStandardCell.UX.interItemSpacing
        group.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0,
                                                      bottom: 0, trailing: PocketStandardCell.UX.interGroupSpacing)

        let section = NSCollectionLayoutSection(group: group)
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                heightDimension: .estimated(34))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize,
                                                                 elementKind: UICollectionView.elementKindSectionHeader,
                                                                 alignment: .top)
        section.boundarySupplementaryItems = [header]
        section.visibleItemsInvalidationHandler = { (visibleItems, point, env) -> Void in
            self.onScroll?(visibleItems)
        }

        let leadingInset = HomepageViewModel.UX.leadingInset(traitCollection: traitCollection)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: leadingInset,
                                                        bottom: HomepageViewModel.UX.spacingBetweenSections, trailing: 0)
        section.orthogonalScrollingBehavior = .continuous
        return section
    }

    func numberOfItemsInSection(for traitCollection: UITraitCollection) -> Int {
        return numberOfCells
    }

    var isEnabled: Bool {
        // For Pocket, the user preference check returns a user preference if it exists in
        // UserDefaults, and, if it does not, it will return a default preference based on
        // a (nimbus pocket section enabled && Pocket.isLocaleSupported) check
        guard featureFlags.isFeatureEnabled(.pocket, checking: .buildAndUser) else { return false }

        return true
    }

    var hasData: Bool {
        return !pocketStoriesViewModels.isEmpty
    }

    func updateData(completion: @escaping () -> Void) {
        Task {
            await updatePocketSites()
            completion()
        }
    }
}

// MARK: FxHomeSectionHandler
extension PocketViewModel: HomepageSectionHandler {

    func configure(_ collectionView: UICollectionView,
                   at indexPath: IndexPath) -> UICollectionViewCell {

        recordSectionHasShown()

        if isStoryCell(index: indexPath.row) {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PocketStandardCell.cellIdentifier, for: indexPath) as! PocketStandardCell
            cell.configure(viewModel: pocketStoriesViewModels[indexPath.row])
            cell.tag = indexPath.item
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PocketDiscoverCell.cellIdentifier, for: indexPath) as! PocketDiscoverCell
            cell.itemTitle.text = .FirefoxHomepage.Pocket.DiscoverMore
            return cell
        }
    }

    func configure(_ cell: UICollectionViewCell,
                   at indexPath: IndexPath) -> UICollectionViewCell {
        // Setup is done through configure(collectionView:indexPath:), shouldn't be called
        return UICollectionViewCell()
    }

    func didSelectItem(at indexPath: IndexPath,
                       homePanelDelegate: HomePanelDelegate?,
                       libraryPanelDelegate: LibraryPanelDelegate?) {

        if isStoryCell(index: indexPath.row) {
            pocketStoriesViewModels[indexPath.row].onTap(indexPath)

        } else {
            showDiscoverMore()
        }
    }

    func handleLongPress(with collectionView: UICollectionView, indexPath: IndexPath) {
        guard let onLongPressTileAction = onLongPressTileAction else { return }

        let site = getSitesDetail(for: indexPath.row)
        let sourceView = collectionView.cellForItem(at: indexPath)
        onLongPressTileAction(site, sourceView)
    }
}