//
//  NewsFeedViewController.swift
//  VKSdkFeed
//
//  Created by Роман Важник on 27/01/2020.
//  Copyright (c) 2020 Роман Важник. All rights reserved.
//
//  This file was generated by the Clean Swift Xcode Templates so
//  you can apply clean architecture to your iOS and Mac projects,
//  see http://clean-swift.com
//

import UIKit

protocol NewsFeedDisplayLogic: class {
    func displayNews(viewModel: NewsFeed.ShowNews.ViewModel)
    func displayUserInfo(viewModel: NewsFeed.ShowUserInfo.ViewModel)
    func displaySearchedGroups(viewModel: NewsFeed.SearchGroup.ViewModel)
}

class NewsFeedViewController: UIViewController, NewsFeedDisplayLogic {
    
    private let configurator: NewsFeedConfiguratorProtocol = NewsFeedConfigurator()
    
    var interactor: NewsFeedBusinessLogic?
    var router: (NSObjectProtocol & NewsFeedRoutingLogic & NewsFeedDataPassing)?
    
    var newsTableView: UITableView!
    var newsFeedViewModel: NewsFeed.ShowNews.ViewModel?
    var newsFeedViewModelSearhResult: NewsFeed.ShowNews.ViewModel?
    
    var refreshControl: UIRefreshControl!
    var bottomRefreshControll: UIActivityIndicatorView!
    
    let titleView = NavigationControllerView()
    
    var isScrollToTopNeeded: Bool = true
    var isSearchedResultsNeedToAppend: Bool = false
    var isNeededToSearch: Bool = true
    var isNewsFeedViewModelNeededToAppend: Bool = false
    
    var frameBeforeImageWasZoomed: CGRect!
    lazy var startImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(performImageZoomOut)))
        return imageView
    }()
    lazy var backgroundViewForImageZoom: UIView = {
        let backgroundView = UIView()
        backgroundView.alpha = 0
        backgroundView.backgroundColor = .black
        backgroundView.frame = view.frame
        return backgroundView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurator.configure(view: self)
        setupNewsTableView()
        setupNavigationBar()
        setupRefreshControl()
        interactor?.getNews(request: NewsFeed.ShowNews.Request())
        interactor?.getUserInfo(request: NewsFeed.ShowUserInfo.Request())
    }
    
    func displaySearchedGroups(viewModel: NewsFeed.SearchGroup.ViewModel) {
        if newsFeedViewModelSearhResult != nil && isSearchedResultsNeedToAppend {
            isSearchedResultsNeedToAppend = false
            guard let news = viewModel.resultOfSearching?.news else { return }
            newsFeedViewModelSearhResult?.news.append(contentsOf: news)
        } else {
            newsFeedViewModelSearhResult = viewModel.resultOfSearching
        }
        newsTableView.reloadData()
        if isScrollToTopNeeded {
            scrollTableViewToTop()
        } else {
            isScrollToTopNeeded = true
        }
    }
    
    func displayNews(viewModel: NewsFeed.ShowNews.ViewModel) {
        DispatchQueue.main.async { [unowned self] in
            if !self.titleView.isSeachTextViewEmpty && self.isNeededToSearch {
                self.isScrollToTopNeeded = false
                let request = NewsFeed.SearchGroup.Request(sourceNewsFeedViewModel: viewModel,
                                                           searchedGroupName: self.titleView.navigationControllerTextView.text!)
                self.interactor?.searchGroupRequest(request: request)
            } else if !self.titleView.isSeachTextViewEmpty && !self.isNeededToSearch {
                self.isNeededToSearch = true
                self.newsFeedViewModelSearhResult = viewModel
                self.newsTableView.reloadData()
            } else {
                if self.newsFeedViewModel != nil && self.isNewsFeedViewModelNeededToAppend {
                    self.newsFeedViewModel?.news.append(contentsOf: viewModel.news)
                } else {
                    self.newsFeedViewModel = viewModel
                }
                self.newsTableView.reloadData()
            }
            self.isNewsFeedViewModelNeededToAppend = false
            self.isSearchedResultsNeedToAppend = false
            self.refreshControl.endRefreshing()
            self.bottomRefreshControll.stopAnimating()
        }
    }
    
    func displayUserInfo(viewModel: NewsFeed.ShowUserInfo.ViewModel) {
        DispatchQueue.main.async { [unowned self] in
            self.titleView.setImage(imageURL: viewModel.imageURL)
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height) {
            if newsFeedViewModel != nil {
                bottomRefreshControll.startAnimating()
                let request = NewsFeed.ShowPreviousNews.Request()
                interactor?.showPreviousNews(request: request)
                self.isNewsFeedViewModelNeededToAppend = true
                self.isSearchedResultsNeedToAppend = true
            }
        }
    }
    
    private func setupNavigationBar() {
        navigationController?.hidesBarsOnSwipe = true
        titleView.navigationControllerTextView.delegate = self
        navigationItem.titleView = titleView
        titleView.delegate = self
    }
    
    private func setupRefreshControl() {
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshNews), for: .valueChanged)
        newsTableView.refreshControl = refreshControl
        definesPresentationContext = true
    }
    
    private func setupNewsTableView() {
        newsTableView = UITableView()
        view.addSubview(newsTableView)
        newsTableView.translatesAutoresizingMaskIntoConstraints = false
        newsTableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        newsTableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        newsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        newsTableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        newsTableView.contentInset.top = 10
        newsTableView.backgroundColor = #colorLiteral(red: 0.368627451, green: 0.5098039216, blue: 0.662745098, alpha: 1)
        newsTableView.delegate = self
        newsTableView.dataSource = self
        newsTableView.register(NewsFeedTableViewCell.self, forCellReuseIdentifier: "newsCell")
        
        setupBottomViewForNewsTableView()
        newsTableView.tableFooterView = bottomRefreshControll
    }
    
    private func setupBottomViewForNewsTableView() {
        bottomRefreshControll = UIActivityIndicatorView()
        bottomRefreshControll.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 40)
        bottomRefreshControll.hidesWhenStopped = true
    }
    
    @objc private func refreshNews() {
        interactor?.getNews(request: NewsFeed.ShowNews.Request())
    }
    
    @objc private func performImageZoomOut() {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            self.backgroundViewForImageZoom.alpha = 0
            self.startImageView.frame = self.frameBeforeImageWasZoomed
        }) { (flag) in
            self.backgroundViewForImageZoom.removeFromSuperview()
            self.startImageView.removeFromSuperview()
        }
    }
    
}

// MARK: - NewsTableViewDelegate and NewsTableViewDataSource
extension NewsFeedViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return titleView.isSeachTextViewEmpty ? newsFeedViewModel?.news.count ?? 0
            : newsFeedViewModelSearhResult?.news.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if !titleView.isSeachTextViewEmpty {
            return newsFeedViewModelSearhResult?.news[indexPath.row].sizes.totalHeight ?? 0
        } else {
            return newsFeedViewModel?.news[indexPath.row].sizes.totalHeight ?? 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "newsCell", for: indexPath) as! NewsFeedTableViewCell
        cell.delegate = self
        var optionalViewModel: NewsFeed.ShowNews.ViewModel.Cell?
        if !titleView.isSeachTextViewEmpty {
            optionalViewModel = newsFeedViewModelSearhResult?.news[indexPath.row]
        } else {
            optionalViewModel = newsFeedViewModel?.news[indexPath.row]
        }
        guard let viewModel = optionalViewModel else { return UITableViewCell() }
        cell.setupElements(with: viewModel)
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        if titleView.isSeachTextViewEmpty {
            return newsFeedViewModel?.news[indexPath.row].sizes.totalHeight ?? 0
        } else {
            return newsFeedViewModelSearhResult?.news[indexPath.row].sizes.totalHeight ?? 0
        }
    }
    
    func scrollTableViewToTop() {
        if newsTableView.numberOfRows(inSection: 0) > 0 {
            let indexPath = IndexPath(row: 0, section: 0)
            newsTableView.scrollToRow(at: indexPath, at: .top, animated: true)
        }
    }
    
}

// MARK: - NewsFeedTableViewCellDelegate
extension NewsFeedViewController: NewsFeedTableViewCellDelegate {
    
    func fullTextRequest(postId: Int) {
        self.isNeededToSearch = false
        var newsFeedViewModel: NewsFeed.ShowNews.ViewModel?
        newsFeedViewModel = titleView.isSeachTextViewEmpty ? self.newsFeedViewModel :
        newsFeedViewModelSearhResult
        interactor?.showFullText(request: NewsFeed.ShowFullPostText.Request(postId: postId,
                                                                            newsFeedViewModel: newsFeedViewModel!))
    }
    
    func performImageZoomIn(imageView: UIImageView) {
        guard let image = imageView.image else { return }
        guard let startFrame = imageView.superview?.convert(imageView.frame, to: nil) else { return }
        if titleView.navigationControllerTextView.isEditing {
            titleView.navigationControllerTextView.endEditing(true)
        }
        frameBeforeImageWasZoomed = startFrame
        startImageView.frame = startFrame
        startImageView.image = image
        guard let keyWindow = (UIApplication.shared.windows.filter {$0.isKeyWindow}.first) else { return }
        keyWindow.addSubview(backgroundViewForImageZoom)
        keyWindow.addSubview(startImageView)
        let viewFrame = view.frame
        
        UIView.animate(withDuration: 0.3) { [unowned self] in
            self.backgroundViewForImageZoom.alpha = 1
            self.startImageView.frame = CGRect(x: 0, y: 0, width: viewFrame.width,
                                                height: startFrame.height)
            self.startImageView.center = self.view.center
        }
    }
}

// MARK: - Work with UITextField from NavigationControllerView
extension NewsFeedViewController: UITextFieldDelegate, NavigationControllerViewDelegate {
    
    func textFieldWasEdited(text: String) {
        interactor?.getNews(request: NewsFeed.ShowNews.Request())
        if !text.isEmpty {
            let request = NewsFeed.SearchGroup.Request(sourceNewsFeedViewModel: newsFeedViewModel,
                                                       searchedGroupName: text)
            interactor?.searchGroupRequest(request: request)
        } else {
            interactor?.getNews(request: NewsFeed.ShowNews.Request())
            newsTableView.reloadData()
            scrollTableViewToTop()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return false
    }
    
}
