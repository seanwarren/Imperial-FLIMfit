#include <QApplication>
#include "FLIMfitWindow.h"

#include <memory>

int main(int argc, char *argv[])
{


   QApplication app(argc, argv);
   app.setOrganizationName("FLIMfit");
   app.setApplicationName("FLIMfit");

   QString default_project = "/Users/sean/Documents/FLIMTestData/Test FLIMfit Project/project.flimfit";
   
   FLIMfitWindow window(default_project);
   window.showMaximized();

   return app.exec();
}