class UsersController < ApplicationController
  before_action :set_user, only: [:show, :check, :edit, :update, :destroy, :edit_basic_info, :update_basic_info, :edit_overwork_request, :update_overwork_request]
  before_action :logged_in_user, only: [:index, :edit, :update, :destroy, :edit_basic_info, :update_basic_info]
  before_action :correct_user, only: [:edit, :update]
  before_action :admin_user, only: [:index, :destroy, :edit_basic_info, :update_basic_info, :working_employee_list]
  before_action :set_one_month, only: [:show, :check]
  before_action :ensure_correct_user, only: [:show, :check]

  def index
    @users = query.order(:id).page(params[:page])
  end
  
  def import
    # fileはtmpに自動で一時保存される
    User.import(params[:file])
    flash[:success] = 'CSVインポートに成功しました。'
    redirect_to users_url
  end
  

  def show
    # ログインユーザーが管理者の場合、別ページへ移動
    if current_user.admin?
      render :edit_basic_info
    else
      @worked_sum = @attendances.where.not(started_at: nil).count
    end
    
    # 一日分の残業申請を行った勤怠データを取得
    @applications_to_A = Attendance.where(authorizer_user_id: "上長Ａ", application_state: "申請中")
    @applications_to_B = Attendance.where(authorizer_user_id: "上長Ｂ", application_state: "申請中")
    # 一ヵ月分の勤怠申請を行った勤怠データを取得
    @month_applications_A = User.where(month_authorizer: "上長Ａ", onemonth_application_state: "申請中")
    @month_applications_B = User.where(month_authorizer: "上長Ｂ", onemonth_application_state: "申請中")
    # 勤怠変更を行った勤怠データを取得
    @edit_applications_A = Attendance.where(change_authorizer: "上長A", application_edit_state: "なし　")
    @edit_applications_B = Attendance.where(change_authorizer: "上長B", application_edit_state: "なし　")
    
  end
  
  def check
    @worked_sum = @attendances.where.not(started_at: nil).count
    @applications_to_A = Attendance.where(authorizer_user_id: "上長Ａ", application_state: "申請中")
    @applications_to_B = Attendance.where(authorizer_user_id: "上長Ｂ", application_state: "申請中")
  end
  
  def ensure_correct_user
    if
      current_user.superior? 
    elsif
      current_user.id != params[:id].to_i
      flash[:danger] = "編集権限がありません。"
      redirect_to users_url
    end
  end

  def new
    @user = User.new
  end

  def create #新規ユーザー作成の処理
    @user = User.new(user_params)
    if @user.save
      log_in @user
      flash[:success] = '新規作成に成功しました。'
      redirect_to @user
    else
      render :new
    end
  end

  def update
    if @user.update_attributes(user_params)
      flash[:success] = "アカウント情報を更新しました。"
      render :edit
    else
      render :edit      
    end
  end

  def destroy # ユーザーを削除する際の処理
    @user.destroy
    flash[:success] = "#{@user.name}のデータを削除しました。"
    redirect_to @user
  end

  def edit_basic_info
    
  end
  
  
  def edit
    
  end
 
  def update_basic_info
    unless @user.update(works_params)
      flash[:danger] = "無効な入力データがあった為、更新をキャンセルしました。"
      redirect_to users_url and return
    else
      User.where(:id => 1..999).update(works_params)
      flash[:success] = "全ユーザーの基本情報を更新しました。"
    end
    redirect_to users_url
  end
  
  def update_user_info
    @user = User.find(params[:id])
    if @user.update_attributes(user_params)
      flash[:success] = "アカウント情報を更新しました。"
      redirect_to users_url
    else
      redirect_to users_url   
    end
  end
  
  def working_employee_list
    @users = User.all.includes(:attendances)
  end
  
  def onemonth_apply
    @user = User.find(params[:id])
    
      if @user.update_attributes(onemonth_apply_params)
        if @user.month_authorizer.present?
          flash[:success] = "今月の勤怠を申請しました"
          redirect_to @user
        else
          flash[:danger] = "所属長を選択してください"
          redirect_to @user
        end  
      end
  end
  
  def onemonth_approval
    @user = User.find(params[:id])
    # 上長Ａあての１ヵ月勤怠申請を全て取得
    @month_applications_A = User.where(month_authorizer: "上長Ａ", onemonth_application_state: "申請中")
    # 名前ごとに分類
    @monthwork_applicationsA = @month_applications_A.group_by do |application|
      User.find_by(id: application.id).name
    end
    # 上長Ｂあての１ヵ月勤怠申請を全て取得
    @month_applications_B = User.where(month_authorizer: "上長Ｂ", onemonth_application_state: "申請中")
  end
  
  def update_onemonth_approval
    @user = User.find(params[:id])
    
      params[:application].each do |id, item|
      @attendance = User.find(id)
      @attendance.update_attributes(item.permit(:check))
      
        if @attendance.check == true
          @attendance.update_attributes(item.permit(:onemonth_application_state))
        elsif @attendance.check == false
          @attendance.update_attributes(item.permit(:check))
        end
      
      end
      flash[:success] = "1ヵ月の勤怠申請を承認 or 否認しました。（※チェックボックスにチェックがついていない項目は反映されません）"
      redirect_to @user
  end
  
  def attendances_edit_log
    @user = User.find(params[:id])
    @edit_data = Attendance.where(application_edit_state: "承認　")
  end
  
  def attendance
    @user = User.find(params[:id])
    # @attendances = @user.attendances.where.not(change_authorizer:"上長A ,上長B" , application_edit_state: "なし　")
    @attendances = @user.attendances
  end
  
  private # strongparameterの設定

    def user_params
      params.require(:user).permit(:name, :email, :affiliation, :employee_number, :uid, :password, :password_confirmation, :basic_work_time, :designated_work_start_time , :designated_work_end_time)
    end

    def works_params
      params.require(:user).permit(:id, :basic_work_time, :designated_work_start_time , :designated_work_end_time)
    end
    
    def onemonth_apply_params
      params.require(:user).permit(:month_authorizer, :onemonth_application_state, :application_month)
    end
    
    
    def query
      if params[:user].present? && params[:user][:name]
        User.where('name LIKE ?', "%#{params[:user][:name]}%")
      else
        User.all
      end
    end
end