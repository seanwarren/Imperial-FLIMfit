#include "FLIMfitWindow.h"

#include <QFileDialog>
#include <QDir>
#include <QFileInfo>
#include <QMessageBox>
#include <QDataStream>
#include "ProgressWidget.h"
#include "ImporterWidget.h"

#include <boost/archive/binary_oarchive.hpp>
#include <boost/archive/binary_iarchive.hpp>
#include <boost/exception/all.hpp>

#include <fstream>

static qint32 flimfit_project_format_version = 1;
static std::string flimfit_project_magic_string = "FLIMfit Project File";


FLIMfitWindow::FLIMfitWindow(const QString& project_file, QWidget* parent) :
QMainWindow(parent)
{
   setupUi(this);
   
   connect(fitting_widget, &FittingWidget::newFitController, this, &FLIMfitWindow::setFitController);
   connect(new_project_action, &QAction::triggered, this, &FLIMfitWindow::newWindow);
   connect(open_project_action, &QAction::triggered, this, &FLIMfitWindow::openProjectFromDialog);
   connect(save_project_action, &QAction::triggered, this, &FLIMfitWindow::saveProject);
   connect(load_data_action, &QAction::triggered, this, &FLIMfitWindow::importData);
   
   if (project_file == QString())
      newProjectFromDialog();
   else
      openProject(project_file);
   
   //loadTestData();
   //fitting_widget->setImageSet(images);
}

void FLIMfitWindow::importData()
{
   ImporterWidget* importer = new ImporterWidget(project_root);
   connect(importer, &ImporterWidget::newImageSet, [&](std::shared_ptr<FLIMImageSet> new_images){
      images = new_images;
      fitting_widget->setImageSet(images);
   });
   importer->show();
}

void FLIMfitWindow::newWindow()
{
   FLIMfitWindow* window = new FLIMfitWindow();
   window->showMaximized();
}

void FLIMfitWindow::saveProject()
{
   try
   {
      std::ofstream ofs(project_file.toStdString(), std::ifstream::binary);
      ofs << flimfit_project_magic_string << "\n";
      ofs << flimfit_project_format_version;
      boost::archive::binary_oarchive oa(ofs);
      // write class instance to archive
      if (images != nullptr)
         oa << images->getImages();
      else
      {
         std::vector<std::shared_ptr<FLIMImage>> empty;
         oa << empty;
      }
   }
   catch(boost::exception& e)
   {
      std::cout << diagnostic_information(e);
      //QString msg = QString("Could not write project file: %1").arg(e.what());
      QMessageBox::critical(this, "Error", "Boost error!");
   }
}

void FLIMfitWindow::newProjectFromDialog()
{
   QString file = QFileDialog::getSaveFileName(this, "Choose project location", QString(), "FLIMfit Project (*.flimfit)");
   
   if (file == QString())
      return;
   
   QSettings settings;
   settings.setValue("last_project_location", file);

   
   QFileInfo info(file);
   QDir path(info.absolutePath());
   QString base_name = info.baseName();
   
   if (!path.mkdir(info.baseName()))
   {
      QMessageBox::critical(this, "Error", "Could not create project folder");
      return;
   }
   
   path.setPath(info.baseName());
   QString new_file = path.filePath(info.fileName());
   
   openProject(new_file);
}


void FLIMfitWindow::openProjectFromDialog()
{
   QString file = QFileDialog::getOpenFileName(this, "Choose FLIMfit project", QString(), "FLIMfit Project (*.flimfit)");
   
   if (!QFileInfo(project_file).exists() && !project_changed)
      openProject(file);
   else
   {
      FLIMfitWindow window(file);
      window.showMaximized();
   }
}

void FLIMfitWindow::openProject(const QString& file)
{
   QFileInfo info(file);
   project_root = info.absolutePath();
   project_file = file;
   
   QSettings settings;
   QStringList recent_projects = settings.value("recent_projects", QStringList()).toStringList();
   recent_projects.append(project_file);
   settings.setValue("recent_projects", recent_projects);
   
   if (info.exists())
   {
      try
      {
         std::ifstream ifs(project_file.toStdString(), std::ifstream::binary);
         
         char magicbuf[30];
         ifs.getline(magicbuf,30);
         if (flimfit_project_magic_string != magicbuf)
            throw std::runtime_error("Not a FLIMfit project file");
         
         quint32 version;
         ifs >> version;
         
         boost::archive::binary_iarchive ia(ifs);
         std::vector<std::shared_ptr<FLIMImage>> new_images;
         ia >> new_images;
         
         for(auto& image : new_images)
         {
            image->setRoot(project_root.toStdString());
            image->init();
         }
         
         images = std::make_shared<FLIMImageSet>();
         images->setImages(new_images);
         fitting_widget->setImageSet(images);
         
         emit openedProject();
         
      }
      catch(std::runtime_error e)
      {
         QString msg = QString("Could not read project file: %1").arg(e.what());
         QMessageBox::critical(this, "Error", msg);
         close();
      }
   }
   else
   {
      saveProject();
   }
}

void FLIMfitWindow::setFitController(std::shared_ptr<FLIMGlobalFitController> controller)
{
   results_widget->setFitController(controller);
   main_tab->setCurrentIndex(2);
   
   ProgressWidget* progress = new ProgressWidget();
   progress->setProgressReporter(controller->getProgressReporter());
   progress_layout->addWidget(progress);
}

void FLIMfitWindow::loadTestData()
{
   QString root = "/Users/sean/Documents/FLIMTestData";
   
   bool use_acceptor_test_data = true;
   
   QString folder, irf_name;
   if (!use_acceptor_test_data)
   {
      folder = QString("%1%2").arg(root).arg("/dual_data");
      irf_name = QString("%1%2").arg(root).arg("/2015-05-15 Dual FRET IRF.csv");
   }
   else
   {
      folder = QString("%1%2").arg(root).arg("/acceptor");
      irf_name = QString("%1%2").arg(root).arg("/acceptor-fret-irf.csv");
   }
   
   auto irf = FLIMImporter::importIRF(irf_name);
   images = FLIMImporter::importFromFolder(folder, project_root);
   
   auto acq = images->getAcquisitionParameters();
   acq->SetIRF(irf);
}
