desc "按群组设置分数"
task "credit:setup" => :environment do
  require 'highline/import'

  puts "", "用户在多个群组时，只会以更大分数覆盖"

  group_name = ask("群组名：")
  group = Group.find_by(name: group_name)
  user_ids = group.user_ids

  credit = ask("分数：").to_i
  user_ids.each do |uid|
    uf = UserCustomField.find_or_initialize_by(user_id: uid, name: 'credit')
    if uf.value.to_i < credit
      uf.value = credit
      uf.save
    end
  end

  puts "", "Done!"
end
