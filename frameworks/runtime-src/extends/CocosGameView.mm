 //
//  CocosGameView.m
//  template
//
//  Created by jiaxu zhang on 16/7/25.
//
//

#import "CocosGameView.h"
#import <Vuforia/Vuforia.h>
#import <Vuforia/State.h>
#import <Vuforia/Tool.h>
#import <Vuforia/Renderer.h>
#import <Vuforia/TrackableResult.h>
#import <Vuforia/VideoBackgroundConfig.h>
#include <Vuforia/ImageTarget.h>
#include <Vuforia/Image.h>

#import "JsMethod.h"
#import "Vuforia/VuforiaController.h"
#import "Vuforia/VuforiaApplicationSession.h"
#include "json/document.h"
#include "json/writer.h"
#include "json/stringbuffer.h"


void ARDrawer::draw()
{
    _customCommand.init(-100);
    _customCommand.func = CC_CALLBACK_0(ARDrawer::drawAR, this);
    cocos2d::Director::getInstance()->getRenderer()->addCommand(&_customCommand);
}

void ARDrawer::drawAR()
{
    Vuforia::State state = Vuforia::Renderer::getInstance().begin();
    Vuforia::Renderer::getInstance().drawVideoBackground();
    Vuforia::Renderer::getInstance().end();
}

void ARDrawer::customProject()
{
    cocos2d::Mat4 projectionMatrix = getCustomProjectMat4();
    auto director = cocos2d::Director::getInstance();
    director->loadIdentityMatrix(cocos2d::MATRIX_STACK_TYPE::MATRIX_STACK_PROJECTION);
    director->multiplyMatrix(cocos2d::MATRIX_STACK_TYPE::MATRIX_STACK_PROJECTION, projectionMatrix);
    cocos2d::Mat4 matrixLookup = getCustomCameraMat4();
    director->multiplyMatrix(cocos2d::MATRIX_STACK_TYPE::MATRIX_STACK_PROJECTION, matrixLookup);
    director->loadIdentityMatrix(cocos2d::MATRIX_STACK_TYPE::MATRIX_STACK_MODELVIEW);
}

cocos2d::Mat4 ARDrawer::getCustomProjectMat4()
{
    const Vuforia::CameraCalibration& cameraCalibration = Vuforia::CameraDevice::getInstance().getCameraCalibration();
    Vuforia::Matrix44F projectionMatrix = Vuforia::Tool::getProjectionGL(cameraCalibration, 2.0f, 5000.0f);
    cocos2d::Mat4 matrixPerspective;
    for (int i = 0; i < 16; ++i) {
        matrixPerspective.m[i] = projectionMatrix.data[i];
    }
    //CameraDevice.getInstance().getCameraCalibration().getFieldOfViewRads()
    _fieldOfView = MATH_RAD_TO_DEG(2 * atan(1.0/matrixPerspective.m[5]));
    //Vuforia::CameraDevice::getInstance().getCameraCalibration().getFieldOfViewRads();
    //_aspectRatio = matrixPerspective.m[5]/matrixPerspective.m[0];
    return matrixPerspective;

}

cocos2d::Mat4 ARDrawer::getCustomCameraMat4()
{
    cocos2d::Mat4 matrixLookup;
    cocos2d::Mat4::createLookAt(getCustomPoint(POINT_TYPE::POINT_EYE), getCustomPoint(POINT_TYPE::POINT_CENTER), getCustomPoint(POINT_TYPE::POINT_UP), &matrixLookup);
    return matrixLookup;
}

cocos2d::Vec3 ARDrawer::getCustomPoint(POINT_TYPE type)
{
    cocos2d::Size size = cocos2d::Director::getInstance()->getWinSize();
    
    float zeye = (size.height * 0.5f) / tan(_fieldOfView*0.5f*3.1415926/180.0);
    if (_fieldOfView == 180) zeye = -1429.0f;
    cocos2d::Vec3 point;
    switch (type) {
        case cocos2d::Drawer::POINT_TYPE::POINT_EYE:
            point = cocos2d::Vec3(size.width/2, size.height/2, zeye);
            break;
        case cocos2d::Drawer::POINT_TYPE::POINT_CENTER:
            point = cocos2d::Vec3(size.width/2, size.height/2, zeye - 10.0f);
            break;
        case cocos2d::Drawer::POINT_TYPE::POINT_UP:
            point = cocos2d::Vec3(0.0f, 1.0f, 0.0f);
            break;
        default:
            break;
    }
    return point;
}


@implementation CocosGameView

- (void) showAR
{
    cocos2d::Director::getInstance()->setDrawer(&drawer);
    cocos2d::Director::getInstance()->setProjection(cocos2d::Director::Projection::CUSTOM);
}

- (void) stopAR
{
    cocos2d::Director::getInstance()->setDrawer(nullptr);
    cocos2d::Director::getInstance()->setProjection(cocos2d::Director::Projection::_3D);
}

- (void)renderFrameVuforia
{
    [self performSelectorOnMainThread:@selector(drawAR)
                           withObject:nil
                        waitUntilDone:NO];
}

-(void) drawAR
{
    Vuforia::State state = Vuforia::Renderer::getInstance().begin();
    [self dealMatix:state];
    Vuforia::Renderer::getInstance().end();
}

-(void) dealMatix:(Vuforia::State)state
{
    rapidjson::Document writedoc;
    writedoc.SetObject();
    rapidjson::Document::AllocatorType& allocator = writedoc.GetAllocator();
    
    rapidjson::Value models(rapidjson::kArrayType);
    for (int i = 0; i < state.getNumTrackableResults(); ++i) {
        const Vuforia::TrackableResult* result = state.getTrackableResult(i);
        const Vuforia::Trackable& trackable = result->getTrackable();
        Vuforia::Matrix44F modelViewMatrix = Vuforia::Tool::convertPose2GLMatrix(result->getPose());
        
        cocos2d::Mat4 mMatrix;
        for (int i = 0; i < 16; ++i) {
            mMatrix.m[i] = modelViewMatrix.data[i];
        };
        float scala = 3.0;
        mMatrix.m[12] += (mMatrix.m[8]  * scala);
        mMatrix.m[13] += (mMatrix.m[9]  * scala);
        mMatrix.m[14] += (mMatrix.m[10] * scala);
        mMatrix.m[15] += (mMatrix.m[11] * scala);
        mMatrix.scale(scala, scala, scala);
        
        cocos2d::Vec3 eye = drawer.getCustomPoint(cocos2d::Drawer::POINT_TYPE::POINT_EYE);
        cocos2d::Mat4 cocosMatrix;
        cocos2d::Mat4::createTranslation(eye, &cocosMatrix);
        cocosMatrix.multiply(mMatrix);
        
        cocos2d::Quaternion quat;
        cocos2d::Vec3 scale;
        cocos2d::Vec3 translation;
        cocosMatrix.decompose(&scale, &quat, &translation);
        
        rapidjson::Value quaternion(rapidjson::kObjectType);
        quaternion.AddMember("x", quat.x, allocator);
        quaternion.AddMember("y", quat.y, allocator);
        quaternion.AddMember("z", quat.z, allocator);
        quaternion.AddMember("w", quat.w, allocator);
        
        rapidjson::Value scaleXYZ(rapidjson::kObjectType);
        scaleXYZ.AddMember("x", scale.x, allocator);
        scaleXYZ.AddMember("y", scale.y, allocator);
        scaleXYZ.AddMember("z", scale.z, allocator);
        
        rapidjson::Value translationXYZ(rapidjson::kObjectType);
        translationXYZ.AddMember("x", translation.x, allocator);
        translationXYZ.AddMember("y", translation.y, allocator);
        translationXYZ.AddMember("z", translation.z, allocator);
        
        rapidjson::Value model(rapidjson::kObjectType);
        rapidjson::Value name(rapidjson::kStringType);
        name.SetString(trackable.getName(), rapidjson::SizeType(strlen(trackable.getName())));
        model.AddMember("name", name, allocator);
        model.AddMember("quaternion", quaternion, allocator);
        model.AddMember("scale", scaleXYZ, allocator);
        model.AddMember("translation", translationXYZ, allocator);
        
        models.PushBack(model, allocator);
    }
    writedoc.AddMember("module", "AR", allocator);
    writedoc.AddMember("models", models, allocator);
    
    rapidjson::StringBuffer buffer;
    rapidjson::Writer<rapidjson::StringBuffer> writer(buffer);
    writedoc.Accept(writer);
    
    std::string json = buffer.GetString();
    NSString *jsonString = [[NSString alloc] initWithCString:json.c_str() encoding:[NSString defaultCStringEncoding]];
    [JsMethodInterface callJsMethod:[jsonString stringByReplacingOccurrencesOfString:@"\n" withString:@""]];
}

@end
