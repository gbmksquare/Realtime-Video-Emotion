//
//  HistoryViewController.swift
//  Emotion
//
//  Created by BumMo Koo on 2016. 11. 12..
//  Copyright © 2016년 BumMo Koo. All rights reserved.
//

import UIKit
import RealmSwift
import SDWebImage

class HistoryViewController: UIViewController {
    @IBOutlet fileprivate weak var collectionView: UICollectionView!
    @IBOutlet fileprivate weak var groupFaceButton: UIBarButtonItem!
    fileprivate var photos: Results<Photo>?
    fileprivate var faces: Results<Face>?
    fileprivate var groups: [[String]]?
    fileprivate var messyGroup: [String]?
    
    fileprivate var realm: Realm?
    fileprivate var token: NotificationToken?
    
    fileprivate var showPhotos = true
    fileprivate var facesGrouped = false
    
    // MARK: View
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.delegate = self
        collectionView.dataSource = self
        
        do {
            let realm = try Realm()
            photos = realm.objects(Photo.self)
            faces = realm.objects(Face.self)
            self.realm = realm
            
            token = realm.addNotificationBlock({ [weak self] (notification, _) in
                self?.collectionView.reloadData()
            })
        } catch {
            
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        collectionView.reloadData()
    }
    
    deinit {
        token?.stop()
    }
    
    // MARK: Action
    @IBAction private func tappedMode(sender: UIButton) {
        showPhotos = !showPhotos
        facesGrouped = false
        collectionView.reloadData()
    }
    
    @IBAction private func tappedGroupFaces(sender: UIBarButtonItem) {
        guard let photos = self.photos else { return }
        var completeCount = 0
        for photo in photos {
            API.detectFaces(photo: photo, handler: { [weak self] (faces) in
                completeCount += 1
                if completeCount == photos.count {
                    guard let results = self?.realm?.objects(IdentifiableFace.self) else { return }
                    var faces = [IdentifiableFace]()
                    for result in results {
                        faces.append(result)
                    }
                    API.groupFaces(faces: faces, handler: { [weak self] (groups, messyGroup) in
                        self?.groups = groups
                        self?.messyGroup = messyGroup
                        self?.facesGrouped = true
                        DispatchQueue.main.async {
                            self?.collectionView.reloadData()
                        }
                    })
                }
            })
        }
    }
    
    @IBAction private func tappedClear(sender: UIBarButtonItem) {
        try? realm?.write { [weak self] in
            self?.realm?.deleteAll()
        }
        SDImageCache.shared().clearDisk()
    }
}

extension HistoryViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    // MARK: Data source
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        if facesGrouped == true {
            var count = 0
            count += groups?.count ?? 0
            count += messyGroup != nil ? 1 : 0
            return count
        } else {
            return 1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if facesGrouped == true {
            if section == groups?.count {
                return messyGroup?.count ?? 0
            } else {
                return groups?[section].count ?? 0
            }
        } else {
            if showPhotos == true {
                return photos?.count ?? 0
            } else {
                return faces?.count ?? 0
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! PhotoCell
        if facesGrouped == true {
            cell.labelBackgroundView.isHidden = true
            if indexPath.section == groups?.count {
                guard let faceId = messyGroup?[indexPath.row] else { return cell }
                guard let face = realm?.object(ofType: IdentifiableFace.self, forPrimaryKey: faceId) else { return cell }
                var image = face.photo?.image
                if let rect = face.faceRect?.cgRect {
                    image = image?.crop(rect: rect)
                }
                cell.imageView.image = image
            } else {
                let group = groups?[indexPath.section]
                guard let faceId = group?[indexPath.row] else { return cell }
                guard let face = realm?.object(ofType: IdentifiableFace.self, forPrimaryKey: faceId) else { return cell }
                var image = face.photo?.image
                if let rect = face.faceRect?.cgRect {
                    image = image?.crop(rect: rect)
                }
                cell.imageView.image = image
            }
        } else {
            if showPhotos == true {
                cell.labelBackgroundView.isHidden = true
                if let photo = photos?[indexPath.row] {
                    cell.imageView.image = photo.image
                }
            } else {
                if let face = faces?[indexPath.row] {
                    var image = face.photo?.image
                    if let rect = face.faceRect?.cgRect {
                        image = image?.crop(rect: rect)
                    }
                    cell.imageView.image = image
                    cell.labelBackgroundView.isHidden = false
                    cell.emotionLabel.text = face.emotion?.findEmotion().emoji
                }
            }
        }
        return cell
    }
    
    // MARK: Delegate flow layout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let side = (collectionView.bounds.width - 2) / 3
        return CGSize(width: side, height: side)
    }
}
