class TableMemosController < ApplicationController
  permits :description

  before_action :redirect_named_path, only: :show

  def show(database_name, name)
    @table_memo = TableMemo.includes(column_memos: :logs).joins(:database_memo).merge(DatabaseMemo.where(name: database_name)).where(name: name).take!
    return unless @table_memo.linked?
    source_table_class = @table_memo.source_table_class
    if source_table_class
      @source_column_classes = source_table_class.columns
      unless @table_memo.masked?
        @source_table_data = fetch_source_table_data(source_table_class, @source_column_classes)
      end
      @source_table_count = source_table_class.count
    end
  end

  def edit(id)
    @table_memo = TableMemo.find(id)
  end

  def update(id, table_memo)
    @table_memo = TableMemo.find(id)
    @table_memo.assign_attributes(table_memo)
    if @table_memo.changed?
      @table_memo.build_log(current_user.id)
      @table_memo.save!
    end
    redirect_to database_memo_table_path(@table_memo.database_memo.name, @table_memo.name)
  end

  def destroy(id)
    table_memo = TableMemo.find(id)
    table_memo.destroy!
    redirect_to database_memo_path(table_memo.database_memo_id)
  end

  private

  def fetch_source_table_data(source_table_class, source_column_classes)
    cache("source_table_data_#{source_table_class.cache_key}", expire: 1.day) do
      column_names = source_column_classes.map(&:name)
      source_table_class.limit(20).pluck(*column_names)
    end
  end

  private

  def redirect_named_path(id = nil)
    return unless id =~ /\A\d+\z/
    table_memo = TableMemo.find(id)
    redirect_to database_memo_table_path(table_memo.database_memo.name, table_memo.name)
  end
end
